import assert from "node:assert/strict";
import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { after, before, type TestContext } from "node:test";

import {
  fauxProvider, fauxAssistantMessage, fauxToolCall,
  InMemoryCredentialStore, InMemoryModelsStore, validateToolArguments,
} from "@earendil-works/pi-ai";
import { convertResponsesTools } from "@earendil-works/pi-ai/api/openai-responses-shared";
import {
  createAgentSession, DefaultResourceLoader, ModelRuntime, SessionManager, SettingsManager,
  type ExtensionAPI, type ExtensionContext, type ToolDefinition,
} from "@earendil-works/pi-coding-agent";

import ctxExtension from "./index.ts";
import { nextReminder, reminderKey, REMINDER_TYPE } from "./pressure.ts";
import { registerRecall } from "./recall.ts";

let directory: string;
const originalAgentDir = process.env.PI_CODING_AGENT_DIR;
before(async () => {
  directory = await mkdtemp(join(tmpdir(), "pi-ctx-test-"));
  process.env.PI_CODING_AGENT_DIR = directory;
  await writeFile(join(directory, "settings.json"), JSON.stringify({
    compaction: { enabled: true, reserveTokens: 16384, keepRecentTokens: 1000 },
  }));
});
after(async () => {
  if (originalAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = originalAgentDir;
  await rm(directory, { recursive: true, force: true });
});

function user(manager: SessionManager, content: string) {
  return manager.appendMessage({ role: "user", content, timestamp: Date.now() });
}
function seed(manager: SessionManager) {
  const id = user(manager, "Original decision: refresh-key-4829.");
  for (let i = 0; i < 30; i++) {
    user(manager, `Work item ${i}`);
    manager.appendMessage(fauxAssistantMessage(`Finished investigation ${i}. ${"evidence ".repeat(100)}`));
  }
  return id;
}
function recordReminder(manager: SessionManager, tokens: number, window = 200000, reserve = 16384) {
  const reminder = nextReminder(manager.getBranch(), tokens, window, reserve);
  if (reminder) manager.appendCustomMessageEntry(REMINDER_TYPE, reminder.text, true, { key: reminder.key, level: reminder.level });
  return reminder;
}

test("milestones escalate once, skip crossed levels, and restore correctly on branch navigation", () => {
  const manager = SessionManager.inMemory();
  const root = user(manager, "Work");
  assert.equal(recordReminder(manager, 128531), undefined);
  assert.equal(recordReminder(manager, 128532)?.level, 0);
  assert.equal(recordReminder(manager, 140000), undefined);
  assert.equal(recordReminder(manager, 156074)?.level, 1);
  assert.equal(recordReminder(manager, 174436)?.level, 2);
  assert.equal(recordReminder(manager, 180000), undefined);
  manager.branch(root);
  assert.equal(recordReminder(manager, 174436)?.level, 2);
  assert.equal(recordReminder(manager, 156074), undefined);
  manager.appendCompaction("Handoff", root, 180000);
  assert.equal(recordReminder(manager, 128532)?.level, 0);
  assert.equal(recordReminder(manager, 75000, 100000, 16384)?.level, 1);
  assert.equal(nextReminder([], 10, 16000, 16384), undefined);
  assert.equal(nextReminder([], Number.NaN, 200000, 16384), undefined);
});

test("reminder state survives persisted resume and resets at native compaction boundaries", async () => {
  const manager = SessionManager.create(directory, join(directory, "sessions"));
  const root = user(manager, "Work");
  manager.appendMessage(fauxAssistantMessage("Starting"));
  recordReminder(manager, 156074);
  const resumed = SessionManager.open(manager.getSessionFile()!);
  assert.equal(recordReminder(resumed, 156074), undefined);
  resumed.appendCompaction("Checkpoint", root, 160000);
  assert.notEqual(reminderKey(manager.getBranch(), 200000, 16384), reminderKey(resumed.getBranch(), 200000, 16384));
});

async function runtime(t: TestContext, options: { empty?: boolean; extraFactory?: (pi: ExtensionAPI) => void } = {}) {
  const faux = fauxProvider({ models: [{ id: "ctx-test", contextWindow: 200000, maxTokens: 4096 }] });
  const modelRuntime = await ModelRuntime.create({
    modelsPath: null,
    refreshOnCreate: false,    credentials: new InMemoryCredentialStore(), modelsStore: new InMemoryModelsStore(),
  });
  modelRuntime.registerNativeProvider(faux.provider);
  await modelRuntime.setRuntimeApiKey(faux.getModel().provider, "test-only");
  const settings = SettingsManager.create(directory, directory, { projectTrusted: false });
  const manager = SessionManager.inMemory(directory);
  const oldId = options.empty ? undefined : seed(manager);
  const loader = new DefaultResourceLoader({
    cwd: directory, agentDir: directory, settingsManager: settings,
    noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true,
    agentsFilesOverride: () => ({ agentsFiles: [] }),
    systemPromptOverride: () => "Test agent.",
    extensionFactories: [ctxExtension, ...(options.extraFactory ? [options.extraFactory] : [])],
  });
  await loader.reload();
  const { session } = await createAgentSession({
    cwd: directory, agentDir: directory, modelRuntime, model: faux.getModel(),
    sessionManager: manager, settingsManager: settings, resourceLoader: loader,
    tools: ["respawn", "recall"],
  });
  const errors: string[] = [];
  await session.bindExtensions({ onError: (error) => errors.push(error.error) });
  t.after(() => session.dispose());
  return { faux, session, manager, oldId, errors, settings };
}

test("real Pi run commits a standalone respawn after its result, retains native tail, and continues exactly once", { timeout: 15000 }, async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([
    fauxAssistantMessage(fauxToolCall("respawn", {}, { id: "checkpoint-1" }), { stopReason: "toolUse" }),
    (_context, options) => {
      assert.equal(options?.maxTokens, 1024);
      assert.equal(_context.tools?.length ?? 0, 0);
      const prompt = JSON.stringify(_context.messages);
      const recentBoundary = prompt.indexOf("Retained recent tail");
      const correction = prompt.indexOf("The old plan is superseded; execute the regression test instead.");
      assert.ok(recentBoundary >= 0 && correction > recentBoundary,
        "The summarizer must see the latest correction in the retained tail, not just older history");
      assert.equal(prompt.indexOf("The old plan is superseded; execute the regression test instead.", correction + 1), -1);
      return fauxAssistantMessage("Decision retained. Next: execute regression test.");
    },
    fauxAssistantMessage("Regression test completed."),
  ]);
  const finished = Promise.withResolvers<void>();
  h.session.subscribe((event) => {
    if (event.type === "agent_settled" && h.manager.getBranch().some((entry) =>
      entry.type === "message" && entry.message.role === "assistant" && entry.message.content.some((part) =>
        part.type === "text" && part.text === "Regression test completed."))) finished.resolve();
  });
  await h.session.prompt("The old plan is superseded; execute the regression test instead.");
  await finished.promise;
  assert.deepEqual(h.errors, []);
  const entries = h.manager.getBranch();
  const compactions = entries.filter((entry) => entry.type === "compaction");
  assert.equal(compactions.length, 1);
  assert.equal(compactions[0].summary, "Decision retained. Next: execute regression test.");
  const resultIndex = entries.findIndex((entry) => entry.type === "message" && entry.message.role === "toolResult" && entry.message.toolName === "respawn");
  assert.ok(resultIndex >= 0 && entries.indexOf(compactions[0]) > resultIndex);
  assert.equal(h.faux.state.callCount, 3);
  assert.ok(compactions[0].usage && compactions[0].usage.totalTokens > 0);
  assert.ok(h.manager.getEntry(h.oldId!));
  assert.ok(h.session.messages.some((message) => message.role === "toolResult" && message.toolName === "respawn"));
  assert.deepEqual(h.session.getActiveToolNames().sort(), ["recall", "respawn"]);
});

test("ordinary manual compaction remains native model summarization", { timeout: 15000 }, async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([fauxAssistantMessage("Native fallback summary"), fauxAssistantMessage("Native turn prefix")]);
  const result = await h.session.compact("Focus on outstanding work");
  assert.equal(result.summary.includes("Native fallback summary"), true);
  assert.equal(h.faux.state.callCount, 2);
  assert.deepEqual(h.errors, []);
});

test("automatic compaction uses Pi's native fallback when no respawn was requested", { timeout: 15000 }, async (t) => {
  const h = await runtime(t, { extraFactory: (pi) => {
    pi.on("message_end", (event) => {
      const message = event.message;
      if (message.role === "assistant" && message.content.some((part) => part.type === "toolCall" && part.id === "pressure")) {
        return { message: { ...message, usage: { ...message.usage, input: 190000,
          output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 190000 } } };
      }
    });
  } });
  h.faux.setResponses([
    fauxAssistantMessage(fauxToolCall("recall", { action: "search", target: "refresh-key", offset: 0, scope: "lineage" }, { id: "pressure" }), { stopReason: "toolUse" }),
    ...Array.from({ length: 3 }, () => fauxAssistantMessage("Native fallback response")),
  ]);
  await h.session.prompt("Continue investigating");
  const compacted = h.manager.getBranch().filter((entry) => entry.type === "compaction");
  assert.equal(compacted.length, 1);
  assert.equal(compacted[0].fromHook, false);
  assert.match(compacted[0].summary, /Native fallback response/);
  assert.deepEqual(h.errors, []);
});

test("Pi reaching its threshold during respawn fulfills that request and queues only one continuation", { timeout: 15000 }, async (t) => {
  const h = await runtime(t, { extraFactory: (pi) => {
    pi.on("message_end", (event) => {
      const message = event.message;
      if (message.role === "assistant" && message.content.some((part) => part.type === "toolCall" && part.id === "urgent")) {
        return { message: { ...message, usage: { ...message.usage, input: 190000,
          output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 190000 } } };
      }
    });
  } });
  h.faux.setResponses([
    fauxAssistantMessage(fauxToolCall("respawn", {}, { id: "urgent" }), { stopReason: "toolUse" }),
    fauxAssistantMessage("Next: finish regression"),
    fauxAssistantMessage("Regression finished"),
  ]);
  const finished = Promise.withResolvers<void>();
  h.session.subscribe((event) => {
    if (event.type === "agent_settled" && h.manager.getBranch().some((entry) =>
      entry.type === "message" && entry.message.role === "assistant" && entry.message.content.some((part) =>
        part.type === "text" && part.text === "Regression finished"))) finished.resolve();
  });
  await h.session.prompt("Continue");
  await finished.promise;
  const compacted = h.manager.getBranch().filter((entry) => entry.type === "compaction");
  assert.equal(compacted.length, 1);
  assert.equal(compacted[0].summary, "Next: finish regression");
  assert.equal(h.faux.state.callCount, 3);
  assert.deepEqual(h.errors, []);
});

test("respawn refuses a mixed tool batch without stopping other work or committing a compaction", { timeout: 15000 }, async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([
    fauxAssistantMessage([
      fauxToolCall("respawn", {}, { id: "mixed-respawn" }),
      fauxToolCall("recall", { action: "search", target: "refresh-key", offset: 0, scope: "lineage" }, { id: "mixed-recall" }),
    ], { stopReason: "toolUse" }),
    fauxAssistantMessage("Continuing normally"),
  ]);
  await h.session.prompt("Investigate");
  const failed = h.manager.getBranch().find((entry) => entry.type === "message"
    && entry.message.role === "toolResult" && entry.message.toolCallId === "mixed-respawn");
  assert.ok(failed?.type === "message" && failed.message.role === "toolResult" && failed.message.isError);
  assert.equal(h.manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
  assert.equal(h.faux.state.callCount, 2);
});

test("cancelled compaction never starts a continuation", { timeout: 15000 }, async (t) => {
  const h = await runtime(t, { extraFactory: (pi) => {
    pi.on("session_before_compact", () => ({ cancel: true }));
  } });
  h.faux.setResponses([
    fauxAssistantMessage(fauxToolCall("respawn", {}, { id: "cancel-1" }), { stopReason: "toolUse" }),
    fauxAssistantMessage("Continue safely"),
  ]);
  const failed = Promise.withResolvers<void>();
  h.session.subscribe((event) => { if (event.type === "compaction_end") failed.resolve(); });
  await h.session.prompt("Work");
  await failed.promise;
  assert.equal(h.manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
  assert.equal(h.faux.state.callCount, 2);
});

test("failed working notes cancel without native summarization fallback or continuation", { timeout: 15000 }, async (t) => {
  for (const response of [
    fauxAssistantMessage("Partial note", { stopReason: "length" }),
    fauxAssistantMessage("", { stopReason: "error", errorMessage: "Provider unavailable" }),
    fauxAssistantMessage("   "),
    fauxAssistantMessage(fauxToolCall("recall", {}), { stopReason: "toolUse" }),
  ]) {
    await t.test(response.stopReason + JSON.stringify(response.content), async (t) => {
      const h = await runtime(t);
      h.faux.setResponses([
        fauxAssistantMessage(fauxToolCall("respawn", {}), { stopReason: "toolUse" }),
        response,
      ]);
      const ended = Promise.withResolvers<void>();
      h.session.subscribe((event) => { if (event.type === "compaction_end") ended.resolve(); });
      await h.session.prompt("Continue");
      await ended.promise;
      assert.equal(h.manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
      assert.equal(h.faux.state.callCount, 2);
      assert.ok(h.manager.getEntry(h.oldId!));
    });
  }
});

test("cancelling the working-note request propagates its signal and preserves history", { timeout: 15000 }, async (t) => {
  const h = await runtime(t);
  const started = Promise.withResolvers<void>();
  const cancelled = Promise.withResolvers<void>();
  const ended = Promise.withResolvers<void>();
  h.session.subscribe((event) => { if (event.type === "compaction_end") ended.resolve(); });
  h.faux.setResponses([
    fauxAssistantMessage(fauxToolCall("respawn", {}), { stopReason: "toolUse" }),
    async (_context, options) => {
      assert.ok(options?.signal);
      options.signal.addEventListener("abort", () => cancelled.resolve(), { once: true });
      started.resolve();
      await cancelled.promise;
      options.signal.throwIfAborted();
      return fauxAssistantMessage("Unreachable");
    },
  ]);
  await h.session.prompt("Continue");
  await started.promise;
  h.session.abortCompaction();
  await cancelled.promise;
  await ended.promise;
  assert.equal(h.manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
  assert.equal(h.faux.state.callCount, 2);
  assert.ok(h.manager.getEntry(h.oldId!));
});

test("reminders reach ongoing tool turns, not a new run after a final answer, and old reminders are filtered", { timeout: 15000 }, async (t) => {
  const seen: unknown[] = [];
  const h = await runtime(t, { extraFactory: (pi) => {
    pi.on("context", (event) => { seen.push(event.messages); });
    pi.on("message_end", (event) => {
      const message = event.message;
      if (message.role === "assistant" && message.content.some((part) => part.type === "toolCall" && part.id === "lookup-1")) {
        return { message: { ...message, usage: { ...message.usage, input: 150000,
          output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 150000 } } };
      }
    });
  } });
  const highUsage = fauxAssistantMessage(fauxToolCall("recall", { action: "search", target: "refresh-key", offset: 0, scope: "lineage" }, { id: "lookup-1" }), { stopReason: "toolUse" });
  h.faux.setResponses([highUsage, fauxAssistantMessage("Answer")]);
  await h.session.prompt("Find the original decision");
  assert.equal(h.faux.state.callCount, 2);
  assert.ok(JSON.stringify(seen.at(-1)).includes("70% milestone"));
  const reminder = h.manager.getBranch().find((entry) => entry.type === "custom_message" && entry.customType === REMINDER_TYPE);
  assert.ok(reminder);
  h.faux.setResponses([fauxAssistantMessage("Native summary"), fauxAssistantMessage("Native prefix"), fauxAssistantMessage("Resumed")]);
  await h.session.compact();
  await h.session.prompt("Continue");
  assert.ok(!JSON.stringify(seen.at(-1)).includes("70% milestone"));
  assert.deepEqual(h.errors, []);
});

function recallHarness(manager = SessionManager.inMemory()) {
  let tool: ToolDefinition | undefined;
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  const sent: unknown[] = [];
  registerRecall({
    registerTool: (definition: ToolDefinition) => { tool = definition; },
    registerCommand: (_name: string, definition: Parameters<ExtensionAPI["registerCommand"]>[1]) => { command = definition; },
    getActiveTools: () => ["recall"],
    sendUserMessage: (...args: unknown[]) => { sent.push(args); },
  } as unknown as ExtensionAPI);
  const context = { sessionManager: manager } as unknown as ExtensionContext;
  return { manager, sent, command, tool: tool!,
    read: async (params: Record<string, unknown>, signal?: AbortSignal) => {
      const validated = validateToolArguments(tool!, fauxToolCall("recall", params));
      return tool!.execute("test", validated, signal, undefined, context);
    } };
}
function details(result: Awaited<ReturnType<ReturnType<typeof recallHarness>["read"]>>) {
  return result.details as { scope: string; next: Record<string, unknown> | null; reads: Record<string, unknown>[] };
}
function text(result: Awaited<ReturnType<ReturnType<typeof recallHarness>["read"]>>) {
  return result.content.filter((part) => part.type === "text").map((part) => part.text).join("\n");
}

test("recall search and read remain valid through normal and strict provider serialization", () => {
  const { tool } = recallHarness();
  for (const strict of [false, true]) {
    const [wire] = convertResponsesTools([tool], { strict });
    assert.ok(wire.type === "function" && wire.parameters);
    const exposed = { ...tool, parameters: wire.parameters as typeof tool.parameters };
    for (const args of [
      { action: "search", target: "", offset: 0, scope: "lineage" },
      { action: "read", target: "abc123", offset: 12000, scope: "all" },
    ]) {
      const call = fauxToolCall("recall", args);
      assert.deepEqual(validateToolArguments(exposed, call), args);
      assert.deepEqual(validateToolArguments(tool, call), args);
      for (const bad of [{ ...args, action: "unknown" }, { ...args, offset: -1 }, { ...args, query: "mixed" }]) {
        assert.throws(() => validateToolArguments(exposed, fauxToolCall("recall", bad)), /Validation failed/);
        assert.throws(() => validateToolArguments(tool, fauxToolCall("recall", bad)), /Validation failed/);
      }
    }
  }
});

test("real Pi run searches compacted history then executes the returned read arguments", { timeout: 15000 }, async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([fauxAssistantMessage("Native summary"), fauxAssistantMessage("Native prefix")]);
  await h.session.compact();
  h.faux.setResponses([
    (context) => {
      assert.doesNotMatch(JSON.stringify(context.messages), /refresh-key-4829/);
      return fauxAssistantMessage(fauxToolCall("recall", {
        action: "search", target: "refresh-key", offset: 0, scope: "lineage",
      }), { stopReason: "toolUse" });
    },
    (context) => {
      const result = context.messages.at(-1);
      assert.ok(result?.role === "toolResult" && !result.isError);
      const body = result.content.filter((part) => part.type === "text").map((part) => part.text).join("\n");
      const match = body.match(/^Read: recall\((.+)\)$/m);
      assert.ok(match);
      const args = JSON.parse(match[1]);
      assert.equal(args.target, h.oldId);
      return fauxAssistantMessage(fauxToolCall("recall", args), { stopReason: "toolUse" });
    },
    (context) => {
      const result = context.messages.at(-1);
      assert.ok(result?.role === "toolResult" && !result.isError);
      assert.match(JSON.stringify(result.content), /Original decision: refresh-key-4829/);
      return fauxAssistantMessage("Recovered original decision");
    },
  ]);
  await h.session.prompt("Recover the original decision from history");
  const last = h.session.messages.at(-1);
  assert.ok(last?.role === "assistant" && last.stopReason === "stop");
  assert.match(JSON.stringify(last.content), /Recovered original decision/);
  assert.equal(h.faux.state.callCount, 5); // Two native summary requests, then search, read, answer.
  assert.deepEqual(h.errors, []);
});

test("recall continuation arguments paginate matches and full text without losing scope", async () => {
  const h = recallHarness();
  const original = user(h.manager, "needle " + "x".repeat(24000) + "end-marker");
  for (let i = 0; i < 6; i++) user(h.manager, `needle ${i}`);
  const page = await h.read({ action: "search", target: "needle", offset: 0, scope: "all" });
  const nextPage = await h.read(details(page).next!);
  assert.equal(details(nextPage).next, null);
  const read = details(nextPage).reads.find((args) => args.target === original);
  assert.ok(read);
  let result = await h.read(read);
  let body = "";
  while (true) {
    assert.equal(details(result).scope, "all");
    body += text(result);
    const next = details(result).next;
    if (!next) break;
    assert.match(text(result), /Continue: recall\(/);
    result = await h.read(next);
  }
  assert.match(body, /end-marker/);
});

test("/recall preserves a natural-language request and queues agent-led recovery", async () => {
  const h = recallHarness();
  await h.command!.handler("  Why did we change the refresh strategy?  ", {} as never);
  const sent = h.sent[0] as [string, { deliverAs: string }];
  assert.ok(sent[0].endsWith("Why did we change the refresh strategy?"));
  assert.equal(sent[1].deliverAs, "followUp");
  await h.command!.handler("", {} as never);
  assert.equal(h.sent.length, 2);
});

test("recall stays branch-scoped, pages full text, ranks keywords, and works after compaction without sidecars", async () => {
  const h = recallHarness();
  const root = user(h.manager, "auth token decision");
  const foreign = user(h.manager, "branch-only-marker");
  h.manager.branch(root);
  const body = "🙂".repeat(15000) + "end-marker";
  const large = user(h.manager, body);
  h.manager.appendCompaction("Summary", large, 40000);
  const search = (target: string, offset = 0) => ({ action: "search", target, offset, scope: "lineage" });
  const read = (target: string, offset = 0, scope = "lineage") => ({ action: "read", target, offset, scope });
  assert.match(text(await h.read(search("auth token"))), /auth token decision/);
  await assert.rejects(h.read(read(foreign)), /scope 'lineage'/);
  assert.match(text(await h.read(read(foreign, 0, "all"))), /branch-only-marker/);
  const first = await h.read(read(large));
  assert.ok(Buffer.byteLength(text(first)) < 50000);
  assert.deepEqual(details(first).next, read(large, 12000));
  assert.match(text(await h.read(read(large, 30000))), /end-marker/);
  await assert.rejects(h.read(search("auth", 100)), /matching entries/);
  await assert.rejects(h.read(read(large, body.length)), /offset/);
  h.manager.appendCustomEntry("private", { value: "secret-marker" });
  assert.doesNotMatch(text(await h.read(search("secret-marker"))), /private/);
  assert.deepEqual((await readdir(directory)).filter((name) => name.startsWith(".pi")), []);
});
