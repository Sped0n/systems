import assert from "node:assert/strict";
import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { after, before, type TestContext } from "node:test";

import {
  fauxAssistantMessage,
  fauxProvider,
  fauxToolCall,
  getCurrentSystemPrompt,
  getCurrentTools,
  InMemoryCredentialStore,
  InMemoryModelsStore,
  validateToolArguments,
  type JsonObject,
} from "@earendil-works/pi-ai";
import {
  createAgentSession,
  estimateTokens,
  DefaultResourceLoader,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  sessionEntryToContextMessages,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionBeforeCompactEvent,
  type ToolDefinition,
} from "@earendil-works/pi-coding-agent";

import { buildBrief } from "./brief.ts";
import { BRIEF_MAX_TOKENS, LARGE_TOOL_RESULT_CHARS } from "./constants.ts";
import ctxExtension from "./index.ts";
import { registerRecall } from "./recall.ts";
import {
  compileTrace,
  maskConsumedToolResults,
  recallTraceEntry,
} from "./view.ts";

let directory: string;
const originalAgentDir = process.env.PI_CODING_AGENT_DIR;
before(async () => {
  directory = await mkdtemp(join(tmpdir(), "pi-ctx-test-"));
  process.env.PI_CODING_AGENT_DIR = directory;
  await writeFile(
    join(directory, "settings.json"),
    JSON.stringify({
      compaction: {
        enabled: true,
        reserveTokens: 16384,
        keepRecentTokens: 1000,
      },
    }),
  );
});
after(async () => {
  if (originalAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = originalAgentDir;
  await rm(directory, { recursive: true, force: true });
});

function user(manager: SessionManager, content: string) {
  return manager.appendMessage({
    role: "user",
    content,
    timestamp: Date.now(),
  });
}
function seed(manager: SessionManager) {
  const id = user(manager, "Original decision: refresh-key-4829.");
  for (let index = 0; index < 30; index++) {
    user(manager, `Work item ${index}`);
    manager.appendMessage(
      fauxAssistantMessage(`Finished ${index}. ${"evidence ".repeat(100)}`),
    );
  }
  return id;
}
function toolResult(
  manager: SessionManager,
  id: string,
  name: string,
  value: string,
  isError = false,
) {
  return manager.appendMessage({
    role: "toolResult",
    toolCallId: id,
    toolName: name,
    content: [{ type: "text", text: value }],
    isError,
    timestamp: Date.now(),
  });
}
function eventFor(
  manager: SessionManager,
  firstKeptEntryId = manager.getLeafId()!,
): SessionBeforeCompactEvent {
  return {
    type: "session_before_compact",
    branchEntries: manager.getBranch(),
    reason: "manual",
    willRetry: false,
    signal: new AbortController().signal,
    preparation: {
      firstKeptEntryId,
      tokensBefore: 40000,
      messagesToSummarize: [],
      turnPrefixMessages: [],
      isSplitTurn: false,
      fileOps: { read: new Set(), written: new Set(), edited: new Set() },
      settings: { enabled: true, reserveTokens: 16384, keepRecentTokens: 1000 },
    },
  };
}
function recallHarness(manager = SessionManager.inMemory()) {
  let tool: ToolDefinition | undefined;
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  const sent: unknown[] = [];
  registerRecall({
    registerTool: (definition: ToolDefinition) => {
      tool = definition;
    },
    registerCommand: (
      _name: string,
      definition: Parameters<ExtensionAPI["registerCommand"]>[1],
    ) => {
      command = definition;
    },
    getActiveTools: () => ["recall"],
    sendUserMessage: (...args: unknown[]) => {
      sent.push(args);
    },
  } as unknown as ExtensionAPI);
  const context = { sessionManager: manager } as unknown as ExtensionContext;
  return {
    manager,
    sent,
    command,
    read: async (params: JsonObject, signal?: AbortSignal) => {
      const validated = validateToolArguments(
        tool!,
        fauxToolCall("recall", params),
      );
      return tool!.execute("test", validated, signal, undefined, context);
    },
  };
}
function resultText(
  result: Awaited<ReturnType<ReturnType<typeof recallHarness>["read"]>>,
) {
  return result.content
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n");
}

async function runtime(
  t: TestContext,
  options: {
    extraFactory?: (pi: ExtensionAPI) => void;
    empty?: boolean;
    contextWindow?: number;
    manager?: SessionManager;
  } = {},
) {
  const faux = fauxProvider({
    models: [
      {
        id: "ctx-test",
        contextWindow: options.contextWindow ?? 272000,
        maxTokens: 8192,
      },
    ],
  });
  const modelRuntime = await ModelRuntime.create({
    modelsPath: null,
    refreshOnCreate: false,
    credentials: new InMemoryCredentialStore(),
    modelsStore: new InMemoryModelsStore(),
  });
  modelRuntime.registerNativeProvider(faux.provider);
  await modelRuntime.setRuntimeApiKey(faux.getModel().provider, "test-only");
  const settings = SettingsManager.create(directory, directory, {
    projectTrusted: false,
  });
  const manager = options.manager ?? SessionManager.inMemory(directory);
  const oldId = options.empty ? undefined : seed(manager);
  const loader = new DefaultResourceLoader({
    cwd: directory,
    agentDir: directory,
    settingsManager: settings,
    noExtensions: true,
    noSkills: true,
    noPromptTemplates: true,
    noThemes: true,
    agentsFilesOverride: () => ({ agentsFiles: [] }),
    extensionFactories: [
      ctxExtension,
      ...(options.extraFactory ? [options.extraFactory] : []),
    ],
  });
  await loader.reload();
  const { session } = await createAgentSession({
    cwd: directory,
    agentDir: directory,
    modelRuntime,
    model: faux.getModel(),
    sessionManager: manager,
    settingsManager: settings,
    resourceLoader: loader,
    tools: ["recall"],
  });
  const errors: string[] = [];
  await session.bindExtensions({
    onError: (error) => errors.push(error.error),
  });
  t.after(() => session.dispose());
  return { faux, session, manager, oldId, errors };
}

test("brief preserves requests, corrections, attempted actions and failed results without resolving them", () => {
  const manager = SessionManager.inMemory();
  const request = user(manager, "Audit only. Do not modify generated files.");
  manager.appendMessage(
    fauxAssistantMessage(
      "I propose editing transport.ts; this is not implemented.",
    ),
  );
  const correction = user(
    manager,
    "Yes, edit transport.ts only. Keep generated files untouched.",
  );
  const call = manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall(
        "edit",
        {
          path: "transport.ts",
          edits: [{ oldText: "old-secret", newText: "new-secret" }],
        },
        { id: "edit-1" },
      ),
      { stopReason: "toolUse" },
    ),
  );
  const failed = toolResult(
    manager,
    "edit-1",
    "edit",
    "permission denied; no file changed",
    true,
  );
  user(manager, "Stop and report the blocker.");
  const event = eventFor(manager);
  const brief = buildBrief(event, 272000);
  assert.equal(brief, buildBrief(event, 272000));
  for (const id of [request, correction, call, failed])
    assert.ok(brief.includes(id));
  assert.ok(brief.indexOf("Audit only") < brief.indexOf("Yes, edit"));
  assert.doesNotMatch(brief, /Stop and report the blocker/); // Already in the raw tail.
  assert.match(brief, /→ error/);
  assert.doesNotMatch(brief, /permission denied; no file changed/);
  assert.match(
    recallTraceEntry(manager.getEntry(failed)!)!.text,
    /permission denied; no file changed/,
  );
  assert.match(brief, /transport.ts/);
  assert.doesNotMatch(brief, /old-secret|new-secret/);
  assert.match(
    recallTraceEntry(manager.getEntry(call)!)!.text,
    /old-secret.*new-secret/,
  );
});

test("brief rebuilds original evidence across checkpoints and respects lineage and canonical edits", () => {
  const manager = SessionManager.inMemory();
  const directive = user(manager, "Never modify vendor sources.");
  user(manager, "Abandoned branch: vendor modifications permitted.");
  manager.branch(directive);
  const omitted = user(manager, "Do not reintroduce this canonical omission.");
  const replaced = user(manager, "Old provider wording.");
  const kept = user(manager, "Current work.");
  manager.appendCompaction(
    "Invented checkpoint authorization: change everything.",
    kept,
    40000,
  );
  manager.appendContextEdit(omitted, null);
  manager.appendContextEdit(replaced, {
    content: "Replacement provider wording.",
  });
  manager.appendCustomMessageEntry(
    "ctx-compaction-continuation",
    "Synthetic user mandate",
    false,
  );
  user(manager, "Use an external patch instead.");
  user(manager, "Continue.");
  const brief = buildBrief(eventFor(manager), 272000);
  assert.match(brief, /Never modify vendor sources/);
  assert.match(brief, /Replacement provider wording/);
  assert.match(brief, /Use an external patch/);
  assert.doesNotMatch(
    brief,
    /Abandoned branch|Invented checkpoint|Synthetic user mandate|Old provider wording|Do not reintroduce/,
  );
  assert.match(
    recallTraceEntry(manager.getEntry(omitted)!)!.text,
    /canonical omission/,
  );
});

test("tool-heavy evidence cannot crowd out user constraints, and huge entries retain explicit omissions", () => {
  const manager = SessionManager.inMemory();
  const root = user(
    manager,
    `Keep hardware read-only. ${"original requirement ".repeat(5000)} Root-end.`,
  );
  for (let index = 0; index < 100; index++) {
    manager.appendMessage(
      fauxAssistantMessage(`Investigation ${index}. ${"work ".repeat(1000)}`),
    );
    toolResult(manager, `call-${index}`, "read", "large result ".repeat(5000));
    user(manager, `Requirement ${index}: ${"constraint ".repeat(100)}`);
  }
  const latest = user(manager, "New correction: do not flash; report only.");
  user(manager, "Continue.");
  const event = eventFor(manager);
  for (const capacity of [16000, 32000, 272000]) {
    const brief = buildBrief(event, capacity);
    assert.ok(brief.length <= Math.min(BRIEF_MAX_TOKENS, capacity / 8) * 4);
    assert.ok(
      estimateTokens({
        role: "compactionSummary",
        summary: brief,
        tokensBefore: event.preparation.tokensBefore,
        timestamp: 0,
      }) <= Math.floor(Math.min(BRIEF_MAX_TOKENS, capacity / 8)),
    );
    // Whole-context usage can change with prompt overhead or masking while
    // these source excerpts are identical; it must not recalibrate brief text.
    assert.equal(
      brief,
      buildBrief(
        {
          ...event,
          preparation: { ...event.preparation, tokensBefore: 200000 },
        },
        capacity,
      ),
    );
    assert.match(brief, /Keep hardware read-only/);
    assert.match(brief, /New correction: do not flash; report only/);
    assert.match(brief, /omitted|excerpt/);
    assert.ok(brief.includes(root));
    assert.ok(brief.includes(latest));
    assert.equal(brief, buildBrief(event, capacity));
  }
});

test("bounded UI preserves older user evidence without duplicating the native tail", () => {
  const manager = SessionManager.inMemory();
  user(manager, "Never modify vendor sources.");
  for (let index = 0; index < 60; index++) {
    manager.appendMessage(
      fauxAssistantMessage(
        `Earlier investigation ${index}. ${"history ".repeat(500)}`,
      ),
    );
  }
  const tailStart = user(manager, "Inspect the parser error.");
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall(
        "bash",
        {
          command: "parser-test",
        },
        { id: "parser-test" },
      ),
      { stopReason: "toolUse" },
    ),
  );
  const failed = toolResult(
    manager,
    "parser-test",
    "bash",
    "FAIL: boundary at byte 42",
    true,
  );
  manager.appendMessage(
    fauxAssistantMessage(
      "I propose an external patch; it has not been applied.",
    ),
  );
  const latest = user(
    manager,
    "Would that patch require changing vendor sources?",
  );
  const brief = buildBrief(eventFor(manager, tailStart), 16000);
  assert.match(brief, /Never modify vendor sources/);
  assert.doesNotMatch(
    brief,
    /Inspect the parser error|FAIL: boundary|I propose an external patch|Would that patch require/,
  );
  assert.doesNotMatch(brief, /Earlier investigation 0\./);
  assert.ok(!brief.includes(failed));
  assert.ok(!brief.includes(latest));
  assert.ok(brief.includes(tailStart));
  assert.doesNotMatch(
    brief,
    /## (Current goal|Accepted decisions|Completed work)/,
  );
});

test("UI keeps call chronology and source coordinates across canonical replacements without inferring file outcomes", () => {
  const manager = SessionManager.inMemory();
  user(manager, "Inspect the parser.");
  const call = (name: string, path: string, id: string) =>
    manager.appendMessage(
      fauxAssistantMessage(fauxToolCall(name, { path }, { id }), {
        stopReason: "toolUse",
      }),
    );
  const firstRead = call("read", "parser.ts", "read-1");
  toolResult(manager, "read-1", "read", "original parser");
  manager.appendMessage(
    fauxAssistantMessage("Propose creating planned.ts, but wait for approval."),
  );
  const hidden = call("write", "hidden.ts", "hidden");
  manager.appendContextEdit(hidden, null);
  const replacement = call("read", "original.ts", "replaced");
  manager.appendContextEdit(replacement, {
    content: [
      fauxToolCall("read", { path: "replacement.ts" }, { id: "replaced" }),
    ],
  });
  const latestRead = call("read", "parser.ts", "read-2");
  toolResult(manager, "read-2", "read", "unchanged parser");
  const edit = call("edit", "parser.ts", "edit-failed");
  toolResult(manager, "edit-failed", "edit", "permission denied", true);
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall("bash", {
        command: "echo 'write fabricated.ts'",
      }),
      { stopReason: "toolUse" },
    ),
  );
  user(manager, "Report only.");
  const brief = buildBrief(eventFor(manager), 32000);
  assert.match(brief, /read path="parser.ts"/);
  assert.match(brief, /edit path="parser.ts"/);
  assert.ok(brief.indexOf(firstRead) < brief.indexOf(latestRead));
  assert.ok(brief.includes(edit));
  assert.match(brief, /replacement.ts/);
  assert.ok(brief.includes(`context replacement of ${replacement}`));
  assert.doesNotMatch(
    brief,
    /original.ts|hidden.ts|Modified:|Created:|permission denied/,
  );
  assert.match(brief, /Propose creating planned.ts, but wait for approval/);
  assert.match(brief, /→ error/);
  const entries = manager.getBranch();
  for (const match of brief.matchAll(/source ([^:;\s]+):(\d+)-(\d+)/g)) {
    const full = recallTraceEntry(manager.getEntry(match[1])!, entries)!;
    const block = full.blocks.find(
      (block) => block.offset === Number(match[2]),
    );
    assert.ok(block);
    assert.equal(full.text.slice(block.offset, Number(match[3])), block.text);
  }
});

test("invalid boundaries and cancellation never produce a brief", () => {
  const manager = SessionManager.inMemory();
  user(manager, "Task");
  assert.throws(
    () => buildBrief(eventFor(manager, "missing"), 272000),
    /boundary/,
  );
  assert.throws(() => buildBrief(eventFor(manager), NaN), /capacity/);
  const event = eventFor(manager);
  const controller = new AbortController();
  controller.abort();
  event.signal = controller.signal;
  assert.throws(() => buildBrief(event, 272000), /abort/i);
});

test("masking protects recent multi-step work and recall results, and every older pointer resolves", async () => {
  const manager = SessionManager.inMemory();
  user(manager, "Inspect files.");
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall("read", { path: "old.ts" }, { id: "old" }),
      { stopReason: "toolUse" },
    ),
  );
  const old = toolResult(
    manager,
    "old",
    "read",
    `old-marker ${"x".repeat(LARGE_TOOL_RESULT_CHARS + 100)}`,
  );
  manager.appendMessage(
    fauxAssistantMessage("Consumed, but still in the working window."),
  );
  let entries = manager.getBranch();
  assert.match(
    JSON.stringify(
      maskConsumedToolResults(
        entries.flatMap(sessionEntryToContextMessages),
        entries,
      ),
    ),
    /old-marker/,
  );
  const recalled = toolResult(
    manager,
    "recall-1",
    "recall",
    `recall-marker ${"y".repeat(13000)}`,
  );
  for (let index = 0; index < 6; index++)
    manager.appendMessage(
      fauxAssistantMessage(`working ${index} ${"z".repeat(8000)}`),
    );
  const recent = toolResult(
    manager,
    "new",
    "read",
    `recent-marker ${"x".repeat(10000)}`,
  );
  manager.appendMessage(
    fauxAssistantMessage("Use the recent result for the next edit."),
  );
  entries = manager.getBranch();
  const messages = entries.flatMap(sessionEntryToContextMessages);
  const before = JSON.stringify(messages);
  const projected = maskConsumedToolResults(messages, entries);
  const text = JSON.stringify(projected);
  assert.doesNotMatch(text, /old-marker/);
  assert.match(text, new RegExp(old));
  assert.match(text, /recent-marker/);
  assert.match(text, /recall-marker/);
  assert.equal(JSON.stringify(messages), before);
  const pointer = projected.find(
    (message) => message.role === "toolResult" && message.toolCallId === "old",
  );
  assert.ok(
    pointer?.role === "toolResult" && pointer.content[0].type === "text",
  );
  const args = JSON.parse(
    pointer.content[0].text.match(/recall\((\{.*\})\)/)![1],
  );
  assert.match(
    resultText(await recallHarness(manager).read(args)),
    /old-marker/,
  );
  assert.ok(recallTraceEntry(manager.getEntry(recalled)!));
  assert.ok(recallTraceEntry(manager.getEntry(recent)!));
});

test("masking leaves ambiguous and edited results alone", () => {
  const manager = SessionManager.inMemory();
  const id = toolResult(manager, "same", "read", "x".repeat(9000));
  for (let index = 0; index < 6; index++)
    manager.appendMessage(fauxAssistantMessage("z".repeat(8000)));
  const entries = manager.getBranch();
  const messages = entries.flatMap(sessionEntryToContextMessages);
  assert.deepEqual(
    maskConsumedToolResults(messages, [...entries, manager.getEntry(id)!]),
    messages,
  );
  const edited = messages.map((message) =>
    message.role === "toolResult"
      ? {
          ...message,
          content: [
            { type: "text" as const, text: "replacement".repeat(1000) },
          ],
        }
      : message,
  );
  assert.deepEqual(maskConsumedToolResults(edited, entries), edited);
});

test("recall recovers full write/edit payloads, recall echoes and paged original text after compaction", async () => {
  const h = recallHarness();
  const original = user(h.manager, `needle ${"x".repeat(24000)} end-marker`);
  const mutation = h.manager.appendMessage(
    fauxAssistantMessage(
      [
        fauxToolCall("write", {
          path: "file.ts",
          content: "complete-write-payload",
        }),
        fauxToolCall("edit", {
          path: "file.ts",
          edits: [{ oldText: "exact-old", newText: "exact-new" }],
        }),
      ],
      { stopReason: "toolUse" },
    ),
  );
  const echo = toolResult(
    h.manager,
    "recall-echo",
    "recall",
    "previous recall evidence",
  );
  const tail = user(h.manager, "Current tail");
  h.manager.appendCompaction("Old summary", tail, 40000);
  const search = await h.read({
    action: "search",
    target: "needle",
    offset: 0,
    scope: "lineage",
  });
  assert.match(resultText(search), new RegExp(original));
  assert.match(resultText(search), /Around: recall/);
  let next: JsonObject | null = {
    action: "read",
    target: original,
    offset: 0,
    scope: "lineage",
  };
  let recovered = "";
  let pages = 0;
  while (next) {
    const result = await h.read(next);
    const text = resultText(result);
    recovered += text
      .slice(text.indexOf("\n") + 1)
      .split("\nContinue: recall(")[0]
      .split("\nAround: recall(")[0];
    next = (result.details as { next: JsonObject | null }).next;
    pages++;
  }
  assert.equal(pages, 3);
  assert.equal(
    recovered,
    recallTraceEntry(h.manager.getEntry(original)!)!.text,
  );
  const read = (target: string) =>
    h.read({ action: "read", target, offset: 0, scope: "lineage" });
  assert.match(resultText(await read(mutation)), /complete-write-payload/);
  assert.match(resultText(await read(mutation)), /exact-old.*exact-new/);
  assert.match(resultText(await read(echo)), /previous recall evidence/);
  assert.match(
    resultText(
      await h.read({
        action: "search",
        target: "previous recall evidence",
        offset: 0,
        scope: "lineage",
      }),
    ),
    /No matching history/,
  );
});

test("UI and adaptive retrieval share exact full-view coordinates and distinguish intent from observation", async () => {
  const h = recallHarness();
  user(h.manager, "Keep the existing API.");
  h.manager.appendMessage(
    fauxAssistantMessage(
      [
        { type: "thinking", thinking: "needle private reasoning" },
        { type: "text", text: "I propose needle; not yet verified. 🐕" },
        fauxToolCall(
          "write",
          { path: "needle.ts", content: "needle payload\nsecond line" },
          { id: "needle-call" },
        ),
      ],
      { stopReason: "toolUse" },
    ),
  );
  toolResult(h.manager, "needle-call", "write", "needle was NOT written", true);
  user(h.manager, "Report only.");
  const brief = buildBrief(eventFor(h.manager), 32000);
  assert.match(brief, /I propose needle; not yet verified/);
  assert.match(brief, /→ error/);
  assert.doesNotMatch(brief, /private reasoning|needle payload|NOT written/);
  const before = compileTrace(h.manager.getBranch());
  for (const block of before) {
    const full = recallTraceEntry(
      h.manager.getEntry(block.entryId)!,
      h.manager.getBranch(),
    )!;
    assert.equal(full.text.slice(block.offset, block.end), block.text);
  }
  user(h.manager, "Appended after the coordinates were issued.");
  assert.deepEqual(
    compileTrace(h.manager.getBranch()).slice(0, before.length),
    before,
  );
  const found = await h.read({
    action: "search",
    target: "needle",
    offset: 0,
    scope: "lineage",
  });
  const text = resultText(found);
  for (const role of ["thinking", "assistant", "tool_call", "tool_result"])
    assert.ok(text.includes(`[${role}]`));
  assert.doesNotMatch(text, /assistant\+tool_call/);
  for (const args of (found.details as { reads: JsonObject[] }).reads)
    assert.match(resultText(await h.read(args)), /needle/);
});

test("literal adaptive search returns usable offsets after Unicode case-expanding text", async () => {
  const h = recallHarness();
  user(h.manager, `${"İ".repeat(1000)} Needle[1].ts`);
  user(h.manager, "needle11ats is not the same literal.");
  const found = await h.read({
    action: "search",
    target: "needle[1].ts",
    offset: 0,
    scope: "lineage",
  });
  const details = found.details as { total: number; reads: JsonObject[] };
  assert.equal(details.total, 1);
  assert.match(resultText(await h.read(details.reads[0])), /Needle\[1\]\.ts/);
});

test("short middle user constraints stay visible amid long assistant turns across repeated compactions", () => {
  const manager = SessionManager.inMemory();
  const requests: string[] = [];
  for (let index = 0; index < 20; index++) {
    requests.push(
      `Constraint ${index}: preserve compatibility for device ${index}.`,
    );
    user(manager, requests[index]);
    manager.appendMessage(fauxAssistantMessage("analysis ".repeat(3000)));
  }
  const tail = user(manager, "Continue inspecting.");
  const first = buildBrief(eventFor(manager, tail), 32000);
  for (const request of requests) assert.ok(first.includes(request));
  manager.appendCompaction(first, tail, 50000);
  user(manager, "Do not change the API.");
  const secondTail = user(manager, "Continue.");
  const second = buildBrief(eventFor(manager, secondTail), 32000);
  for (const request of requests) assert.ok(second.includes(request));
  assert.match(second, /Do not change the API/);
  assert.equal((second.match(/# Session UI view/g) ?? []).length, 1);
});

test("recall neighborhoods reconstruct proposal, acceptance, action and result in lineage order", async () => {
  const h = recallHarness();
  user(h.manager, "Read-only inspection first.");
  const proposal = h.manager.appendMessage(
    fauxAssistantMessage("Propose patching parser.ts."),
  );
  user(h.manager, "Approved: parser.ts only.");
  const action = h.manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall(
        "edit",
        { path: "parser.ts", oldText: "old", newText: "new" },
        { id: "patch" },
      ),
      { stopReason: "toolUse" },
    ),
  );
  toolResult(h.manager, "patch", "edit", "Patch applied; tests not yet run.");
  user(h.manager, "Now run the parser tests.");
  const around = await h.read({
    action: "around",
    target: action,
    offset: 0,
    scope: "lineage",
  });
  const text = resultText(around);
  assert.ok(text.indexOf("Propose patching") < text.indexOf("Approved:"));
  assert.ok(text.indexOf("Approved:") < text.indexOf("edit (call patch)"));
  assert.match(text, /Patch applied; tests not yet run/);
  assert.match(text, /Now run the parser tests/);
  h.manager.branch(proposal);
  user(h.manager, "Actually, no edits.");
  await assert.rejects(
    h.read({ action: "read", target: action, offset: 0, scope: "lineage" }),
    /no recallable text/,
  );
  const active = resultText(
    await h.read({
      action: "around",
      target: proposal,
      offset: 0,
      scope: "lineage",
    }),
  );
  assert.doesNotMatch(active, /Approved:|Patch applied/);
  assert.match(active, /Actually, no edits/);
  assert.match(
    resultText(
      await h.read({ action: "read", target: action, offset: 0, scope: "all" }),
    ),
    /parser.ts/,
  );
});

test("recall neighborhoods and search are bounded and pageable, and invalid requests fail explicitly", async () => {
  const h = recallHarness();
  const ids = Array.from({ length: 12 }, (_, i) =>
    user(h.manager, `match-${i} ${"x".repeat(2000)}`),
  );
  const params = {
    action: "around",
    target: ids[2],
    offset: 0,
    scope: "lineage",
  };
  const first = await h.read(params);
  assert.ok(resultText(first).length < 8000);
  const second = await h.read((first.details as { next: JsonObject }).next);
  assert.match(resultText(second), /match-5/);
  assert.doesNotMatch(resultText(second), /match-4 /);
  const search = await h.read({ ...params, action: "search", target: "match" });
  assert.ok(resultText(search).length < 8000);
  assert.match(resultText(search), /match-11/);
  await assert.rejects(h.read({ ...params, offset: 1000 }), /offset/);
  await assert.rejects(
    h.read({ ...params, action: "read", offset: 100000 }),
    /offset/,
  );
  await assert.rejects(
    h.read({ ...params, target: "missing" }),
    /no recallable text/,
  );
  await assert.rejects(h.read({ ...params, offset: -1 }));
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(h.read(params, controller.signal), /abort/i);
});

test("manual compaction calls no model, preserves native tail boundaries and persists only session JSONL", async (t) => {
  const sessionDir = await mkdtemp(join(directory, "sessions-"));
  const manager = SessionManager.create(directory, sessionDir);
  const h = await runtime(t, { manager });
  h.faux.setResponses([fauxAssistantMessage("Unexpected provider call")]);
  const before = h.manager.getBranch();
  const result = await h.session.compact("Focus on open blockers");
  assert.equal(h.faux.state.callCount, 0);
  assert.match(result.summary, /Focus on open blockers/);
  assert.ok(result.summary.includes(h.oldId!));
  assert.deepEqual(h.manager.getBranch().slice(0, before.length), before);
  const kept = h.manager.buildContextEntries().slice(1);
  const firstKept = before.findIndex(
    (entry) => entry.id === result.firstKeptEntryId,
  );
  assert.deepEqual(kept, before.slice(firstKept));
  const files = await readdir(sessionDir);
  assert.equal(files.length, 1);
  assert.match(files[0], /\.jsonl$/);
  const reopened = SessionManager.open(h.manager.getSessionFile()!);
  assert.equal(reopened.getBranch().at(-1)?.type, "compaction");
  assert.match(
    resultText(
      await recallHarness(reopened).read({
        action: "read",
        target: h.oldId!,
        offset: 0,
        scope: "lineage",
      }),
    ),
    /refresh-key-4829/,
  );
  assert.deepEqual(h.errors, []);
});

test("native threshold scheduling uses the selected 272k capacity, not a guessed 32k window", async (t) => {
  const h = await runtime(t);
  const response = fauxAssistantMessage("Continue normally");
  response.usage = { ...response.usage, input: 40000, totalTokens: 40000 };
  h.faux.setResponses([response]);
  await h.session.prompt("Continue investigating.");
  assert.equal(
    h.manager.getBranch().filter((entry) => entry.type === "compaction").length,
    0,
  );
  assert.equal(h.faux.state.callCount, 1);
  assert.deepEqual(h.errors, []);
});

test("native automatic compaction continues the tool loop once without a summary model call or repeat compaction", async (t) => {
  const h = await runtime(t, {
    extraFactory: (pi) => {
      pi.on("message_end", (event) => {
        const message = event.message;
        if (
          message.role === "assistant" &&
          message.content.some(
            (part) => part.type === "toolCall" && part.id === "auto-pressure",
          )
        )
          return {
            message: {
              ...message,
              usage: { ...message.usage, input: 265000, totalTokens: 265000 },
            },
          };
      });
    },
  });
  let resumed = "";
  h.faux.setResponses([
    fauxAssistantMessage(
      fauxToolCall(
        "recall",
        {
          action: "search",
          target: "refresh-key",
          offset: 0,
          scope: "lineage",
        },
        { id: "auto-pressure" },
      ),
      { stopReason: "toolUse" },
    ),
    (context) => {
      resumed = JSON.stringify(context.messages);
      return fauxAssistantMessage("Continued after compaction.");
    },
  ]);
  await h.session.prompt("Continue investigating.");
  const compacted = h.manager
    .getBranch()
    .filter((entry) => entry.type === "compaction");
  assert.equal(compacted.length, 1);
  assert.equal(compacted[0].fromHook, true);
  assert.match(compacted[0].summary, /Original decision/);
  assert.match(resumed, /auto-pressure/);
  assert.equal(h.faux.state.callCount, 2);
  assert.deepEqual(h.errors, []);
});

test("native overflow recovery retries once using the deterministic brief", async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([
    fauxAssistantMessage("", {
      stopReason: "error",
      errorMessage: "maximum context length exceeded",
    }),
    fauxAssistantMessage("Recovered."),
  ]);
  await h.session.prompt("Continue after overflow.");
  assert.equal(
    h.manager.getBranch().filter((entry) => entry.type === "compaction").length,
    1,
  );
  assert.equal(h.faux.state.callCount, 2);
  assert.deepEqual(h.errors, []);
});

test("compaction failure commits nothing and never falls back to a model call", async (t) => {
  const h = await runtime(t, {
    extraFactory: (pi) => {
      pi.on("session_before_compact", (event) => {
        event.signal.throwIfAborted();
        return { cancel: true };
      });
    },
  });
  const before = h.manager.getBranch();
  await assert.rejects(h.session.compact(), /cancelled|failed/i);
  assert.equal(h.faux.state.callCount, 0);
  assert.deepEqual(h.manager.getBranch(), before);
});

test("compaction cannot replace evidence with pointers while recall is restricted", async (t) => {
  const h = await runtime(t);
  h.session.setActiveToolsByName([]);
  const before = h.manager.getBranch();
  await assert.rejects(h.session.compact(), /cancelled|failed/i);
  assert.deepEqual(h.manager.getBranch(), before);
  assert.equal(h.faux.state.callCount, 0);
});

test("canonical provider edits survive masking while recall retains original history", async (t) => {
  const h = await runtime(t, { empty: true });
  const omitted = user(h.manager, "Omit this from provider context.");
  const replaced = user(h.manager, "Original wording retained in history.");
  h.manager.appendContextEdit(omitted, null);
  h.manager.appendContextEdit(replaced, {
    content: [{ type: "text", text: "Replacement provider wording." }],
  });
  h.session.refreshContext();
  let request = "";
  h.faux.setResponses([
    (context) => {
      request = JSON.stringify(context.messages);
      return fauxAssistantMessage("Done.");
    },
  ]);
  await h.session.prompt("Continue with edited context.");
  assert.doesNotMatch(
    request,
    /Omit this from provider context|Original wording retained in history/,
  );
  assert.match(request, /Replacement provider wording/);
  assert.match(
    JSON.stringify(compileTrace(h.manager.getBranch())),
    /Original wording retained in history/,
  );
  assert.deepEqual(h.errors, []);
});

test("Pi's prompt exposes evidence-backed recall without actor compaction instructions", async (t) => {
  const h = await runtime(t);
  let prompt = "";
  let tools: string[] = [];
  h.faux.setResponses([
    (context) => {
      prompt = getCurrentSystemPrompt(context.messages);
      tools = getCurrentTools(context.messages)?.map((tool) => tool.name) ?? [];
      return fauxAssistantMessage("Done.");
    },
  ]);
  await h.session.prompt("Inspect current context tools.");
  assert.deepEqual(tools, ["recall"]);
  assert.match(prompt, /recall the original user message/);
  assert.doesNotMatch(
    prompt,
    /Use compact at|Call compact alone|context-pressure/,
  );
});

test("tool restrictions leave original results visible when recall is unavailable", async (t) => {
  const h = await runtime(t, { empty: true });
  toolResult(
    h.manager,
    "old-read",
    "read",
    `must-stay-visible ${"x".repeat(9000)}`,
  );
  for (let index = 0; index < 6; index++)
    h.manager.appendMessage(fauxAssistantMessage("z".repeat(8000)));
  h.session.refreshContext();
  h.session.setActiveToolsByName([]);
  let request = "";
  h.faux.setResponses([
    (context) => {
      request = JSON.stringify(context.messages);
      return fauxAssistantMessage("Done.");
    },
  ]);
  await h.session.prompt("Continue without recall.");
  assert.match(request, /must-stay-visible/);
  assert.doesNotMatch(request, /Older read output omitted/);
  assert.deepEqual(h.errors, []);
});

test("/recall asks the main model to reconstruct evidence rather than scheduling a separate assistant", async () => {
  const h = recallHarness();
  await h.command!.handler("What was approved but not verified?", {} as never);
  assert.equal(h.sent.length, 1);
  const [message, options] = h.sent[0] as [string, unknown];
  assert.match(message, /What was approved but not verified/);
  assert.match(message, /action:'around'/);
  assert.match(
    message,
    /proposal, user acceptance or correction, action, and validation/,
  );
  assert.deepEqual(options, { deliverAs: "followUp" });
});
