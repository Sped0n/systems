import assert from "node:assert/strict";
import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { after, before, type TestContext } from "node:test";

import {
  fauxAssistantMessage,
  fauxProvider,
  fauxToolCall,
  InMemoryCredentialStore,
  InMemoryModelsStore,
  validateToolArguments,
} from "@earendil-works/pi-ai";
import {
  createAgentSession,
  DefaultResourceLoader,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  sessionEntryToContextMessages,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolDefinition,
} from "@earendil-works/pi-coding-agent";

import {
  COMPACTION_CONTINUATION,
  COMPACTION_CONTINUATION_TYPE,
  CONTEXT_PRESSURE_THRESHOLDS,
  LARGE_TOOL_RESULT_CHARS,
  OBSERVATION_MAX_OUTPUT_TOKENS,
} from "./constants.ts";
import ctxExtension from "./index.ts";
import { buildObservationPrompt } from "./observer.ts";
import { contextPressure, renderContextPressure } from "./pressure.ts";
import { registerRecall } from "./recall.ts";
import {
  compileTrace,
  compileTraceEntry,
  maskConsumedToolResults,
  renderTrace,
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

test("shared trace compiler preserves coordinates while omitting mutation payloads and recall echoes", () => {
  const manager = SessionManager.inMemory();
  const source = user(manager, "Do not modify generated files.");
  const write = manager.appendMessage(
    fauxAssistantMessage(
      [
        { type: "text", text: "The invariant belongs in transport.ts." },
        fauxToolCall(
          "write",
          { path: "generated.ts", content: "secret-payload" },
          { id: "write-1" },
        ),
        fauxToolCall(
          "edit",
          {
            path: "transport.ts",
            edits: [{ oldText: "old-secret", newText: "new-secret" }],
          },
          { id: "edit-1" },
        ),
      ],
      { stopReason: "toolUse" },
    ),
  );
  const failed = toolResult(
    manager,
    "write-1",
    "write",
    "permission denied",
    true,
  );
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall(
        "recall",
        { action: "search", target: "secret", offset: 0, scope: "lineage" },
        { id: "recall-1" },
      ),
      { stopReason: "toolUse" },
    ),
  );
  toolResult(manager, "recall-1", "recall", "recall echo");

  const blocks = compileTrace(manager.getBranch());
  const rendered = renderTrace(blocks, 4096);
  assert.equal(blocks[0]?.timestamp, manager.getEntry(source)?.timestamp);
  assert.match(rendered, new RegExp(`entry ${source}; user`));
  assert.match(rendered, new RegExp(`entry ${write}; assistant`));
  assert.match(rendered, /write\(.*generated\.ts/);
  assert.match(rendered, /\[payload omitted\]/);
  assert.match(rendered, /1 edit payload\(s\) omitted/);
  assert.doesNotMatch(
    rendered,
    /secret-payload|old-secret|new-secret|recall echo/,
  );
  assert.match(rendered, new RegExp(`entry ${failed}; tool_result`));
  assert.match(rendered, /permission denied/);
});

test("trace rendering is bounded with deterministic head and tail coordinates", () => {
  const manager = SessionManager.inMemory();
  const first = user(manager, `first-marker ${"a".repeat(3000)}`);
  for (let index = 0; index < 8; index++)
    user(manager, `middle-${index} ${"m".repeat(3000)}`);
  const last = user(manager, `last-marker ${"z".repeat(3000)}`);
  const rendered = renderTrace(compileTrace(manager.getBranch()), 1800);
  assert.ok(rendered.length <= 7200);
  assert.match(rendered, new RegExp(first));
  assert.match(rendered, new RegExp(last));
  assert.match(rendered, /omitted to fit the observer input/);
});

test("stateless masking uses exact entries and never masks unconsumed or stored results", () => {
  const manager = SessionManager.inMemory();
  user(manager, "Inspect both files.");
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall("read", { path: "old.ts" }, { id: "same" }),
      {
        stopReason: "toolUse",
      },
    ),
  );
  const consumed = toolResult(
    manager,
    "same",
    "read",
    `old-marker ${"x".repeat(LARGE_TOOL_RESULT_CHARS + 100)}`,
  );
  manager.appendMessage(fauxAssistantMessage("The old result was consumed."));
  manager.appendMessage(
    fauxAssistantMessage(
      fauxToolCall("read", { path: "new.ts" }, { id: "same" }),
      {
        stopReason: "toolUse",
      },
    ),
  );
  const unconsumed = toolResult(
    manager,
    "same",
    "read",
    `new-marker ${"y".repeat(LARGE_TOOL_RESULT_CHARS + 100)}`,
  );
  const entries = manager.getBranch();
  const projected = maskConsumedToolResults(
    structuredClone(entries.flatMap(sessionEntryToContextMessages)),
    entries,
  );
  assert.match(JSON.stringify(projected), new RegExp(`recall.*${consumed}`));
  assert.doesNotMatch(JSON.stringify(projected), /old-marker/);
  assert.match(JSON.stringify(projected), /new-marker/);
  assert.match(JSON.stringify(manager.getEntry(consumed)), /old-marker/);
  assert.match(JSON.stringify(manager.getEntry(unconsumed)), /new-marker/);
});

test("pressure calculation is pure, tiered at 60/75/90, and renders actual usage", () => {
  assert.deepEqual(CONTEXT_PRESSURE_THRESHOLDS, {
    advisory: 0.6,
    high: 0.75,
    critical: 0.9,
  });
  assert.equal(contextPressure(59, 110, 10), undefined);
  const advisory = contextPressure(60, 110, 10)!;
  assert.equal(advisory.level, "advisory");
  assert.match(renderContextPressure(advisory), /Do not compact solely/);
  assert.equal(contextPressure(75, 110, 10)?.level, "high");
  const critical = contextPressure(95, 110, 10)!;
  assert.equal(critical.level, "critical");
  assert.match(renderContextPressure(critical), /used-tokens="95"/);
  assert.match(renderContextPressure(critical), /budget-tokens="100"/);
  assert.match(renderContextPressure(critical), /remaining-tokens="5"/);
  assert.match(renderContextPressure(critical), /5 estimated tokens remain/);
  assert.match(renderContextPressure(critical), /usage="95\.0%"/);
  assert.equal(contextPressure(null, 100, 10), undefined);
  assert.equal(contextPressure(10, 10, 10), undefined);
});

test("observer preserves user directives omitted from a tool-heavy general trace", () => {
  const manager = SessionManager.inMemory();
  manager.appendMessage(fauxAssistantMessage(`before ${"x".repeat(50_000)}`));
  const directive = user(manager, "Never place build output in tmpfs.");
  manager.appendMessage(fauxAssistantMessage(`after ${"y".repeat(50_000)}`));
  const prompt = buildObservationPrompt({
    compactedEntries: manager.getBranch(),
    retainedEntries: [],
  });
  const directiveEvidence =
    prompt.match(
      /<user-directive-evidence>([\s\S]*?)<\/user-directive-evidence>/,
    )?.[1] ?? "";
  const generalTrace =
    prompt.match(
      /<newly-compacted-trace>([\s\S]*?)<\/newly-compacted-trace>/,
    )?.[1] ?? "";
  assert.match(directiveEvidence, new RegExp(`entry ${directive}`));
  assert.match(directiveEvidence, /Never place build output in tmpfs/);
  assert.doesNotMatch(generalTrace, /Never place build output in tmpfs/);
});

test("observer prompt rewrites previous memory from compacted and retained shared views", () => {
  const manager = SessionManager.inMemory();
  user(manager, "Old requirement.");
  user(manager, COMPACTION_CONTINUATION);
  const split = manager.getBranch().length;
  user(manager, "New correction.");
  const prompt = buildObservationPrompt({
    previousObservation: "## Current task\nOld task",
    compactedEntries: manager.getBranch().slice(0, split),
    retainedEntries: manager.getBranch().slice(split),
    focus: "Focus on blockers",
  });
  assert.match(prompt, /^<conversation>/);
  assert.match(prompt, /<user-directive-evidence>[\s\S]*Old requirement/);
  assert.doesNotMatch(
    prompt.match(
      /<user-directive-evidence>([\s\S]*?)<\/user-directive-evidence>/,
    )?.[1] ?? "",
    new RegExp(COMPACTION_CONTINUATION),
  );
  assert.match(prompt, /<newly-compacted-trace>[\s\S]*Old requirement/);
  assert.match(prompt, /<retained-tail-trace>[\s\S]*New correction/);
  assert.ok(
    prompt.indexOf("</conversation>") <
      prompt.indexOf("<previous-observation>"),
  );
  assert.match(prompt, /Additional focus: Focus on blockers$/);
  assert.doesNotMatch(prompt, /<focus>/);
  assert.match(prompt, /Use this exact format:/);
  assert.match(prompt, /## Active user directives/);
  assert.match(prompt, /## Accepted decisions/);
  assert.match(prompt, /## Current state/);
  assert.match(prompt, /task or phase change alone does not revoke it/);
});

async function runtime(
  t: TestContext,
  options: { extraFactory?: (pi: ExtensionAPI) => void; empty?: boolean } = {},
) {
  const faux = fauxProvider({
    models: [{ id: "ctx-test", contextWindow: 200000, maxTokens: 65536 }],
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
  const manager = SessionManager.inMemory(directory);
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
    systemPromptOverride: () => "Test agent.",
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
    tools: ["compact", "recall"],
  });
  const errors: string[] = [];
  await session.bindExtensions({
    onError: (error) => errors.push(error.error),
  });
  t.after(() => session.dispose());
  return { faux, session, manager, oldId, errors };
}

const observation = `## Current task
Run the regression test.

## Active user directives
- Preserve original history.

## Accepted decisions
- Use the existing regression harness.

## Current state
- Investigation complete.

## Open work
- Run tests.

## Suggested next action
Run the regression test.`;

test(
  "compact runs observational compaction after its standalone result and continues exactly once",
  { timeout: 15000 },
  async (t) => {
    const h = await runtime(t);
    h.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("compact", {}, { id: "compact-1" }), {
        stopReason: "toolUse",
      }),
      (context, options) => {
        assert.equal(options?.maxTokens, OBSERVATION_MAX_OUTPUT_TOKENS);
        assert.equal(options?.cacheRetention, "none");
        assert.match(options?.sessionId ?? "", /:ctx-observer:/);
        assert.equal(context.tools?.length ?? 0, 0);
        assert.match(
          context.systemPrompt ?? "",
          /Do NOT continue the conversation/,
        );
        assert.match(context.systemPrompt ?? "", /ONLY output/);
        const prompt = JSON.stringify(context.messages);
        assert.match(prompt, /newly-compacted-trace/);
        assert.match(prompt, /retained-tail-trace/);
        assert.doesNotMatch(prompt, /ctx-observational-compact/);
        return fauxAssistantMessage(observation);
      },
      fauxAssistantMessage("Regression test completed."),
    ]);
    const finished = Promise.withResolvers<void>();
    h.session.subscribe((event) => {
      if (
        event.type === "agent_settled" &&
        h.manager
          .getBranch()
          .some(
            (entry) =>
              entry.type === "message" &&
              entry.message.role === "assistant" &&
              entry.message.content.some(
                (part) =>
                  part.type === "text" &&
                  part.text === "Regression test completed.",
              ),
          )
      )
        finished.resolve();
    });
    await h.session.prompt("Continue the work.");
    await finished.promise;
    const entries = h.manager.getBranch();
    const compacted = entries.filter((entry) => entry.type === "compaction");
    assert.equal(compacted.length, 1);
    assert.equal(compacted[0].summary, observation);
    assert.deepEqual(Object.keys(compacted[0].details as object).sort(), [
      "compactor",
      "modifiedFiles",
      "readFiles",
    ]);
    const resultIndex = entries.findIndex(
      (entry) =>
        entry.type === "message" &&
        entry.message.role === "toolResult" &&
        entry.message.toolName === "compact",
    );
    assert.ok(resultIndex >= 0 && entries.indexOf(compacted[0]) > resultIndex);
    assert.equal(h.faux.state.callCount, 3);
    assert.ok(h.manager.getEntry(h.oldId!));
    assert.equal(
      entries.some(
        (entry) =>
          entry.type === "message" &&
          entry.message.role === "user" &&
          entry.message.content === COMPACTION_CONTINUATION,
      ),
      false,
    );
    assert.ok(
      entries.some(
        (entry) =>
          entry.type === "custom_message" &&
          entry.customType === COMPACTION_CONTINUATION_TYPE,
      ),
    );
    assert.deepEqual(h.errors, []);
  },
);

test("manual compaction uses the observer and passes user focus", async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([
    (context) => {
      assert.match(JSON.stringify(context.messages), /Focus on open blockers/);
      return fauxAssistantMessage(observation);
    },
  ]);
  const result = await h.session.compact("Focus on open blockers");
  assert.equal(result.summary, observation);
  assert.equal(h.faux.state.callCount, 1);
  assert.equal(
    h.manager.getBranch().filter((entry) => entry.type === "compaction").length,
    1,
  );
});

test("automatic threshold compaction uses the same observer", async (t) => {
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
              usage: { ...message.usage, input: 190000, totalTokens: 190000 },
            },
          };
      });
    },
  });
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
    fauxAssistantMessage(observation),
    fauxAssistantMessage("Continued after automatic compaction."),
  ]);
  await h.session.prompt("Continue the investigation.");
  const compacted = h.manager
    .getBranch()
    .filter((entry) => entry.type === "compaction");
  assert.equal(compacted.length, 1);
  assert.equal(compacted[0].summary, observation);
  assert.equal(compacted[0].fromHook, true);
  assert.equal(h.faux.state.callCount, 3);
});

test("incomplete observation cancels compaction without native fallback", async (t) => {
  const h = await runtime(t);
  h.faux.setResponses([
    fauxAssistantMessage("Partial observation", { stopReason: "length" }),
    fauxAssistantMessage("native fallback must not run"),
  ]);
  await assert.rejects(h.session.compact(), /cancelled|failed/i);
  assert.equal(h.faux.state.callCount, 1);
  assert.equal(
    h.manager.getBranch().filter((entry) => entry.type === "compaction").length,
    0,
  );
  assert.ok(h.manager.getEntry(h.oldId!));
});

test("pressure annotation is transient provider context only", async (t) => {
  const observed: unknown[] = [];
  const h = await runtime(t, {
    extraFactory: (pi) => {
      pi.on("context", (event) => {
        observed.push(event.messages);
      });
      pi.on("message_end", (event) => {
        const message = event.message;
        if (
          message.role === "assistant" &&
          message.content.some(
            (part) => part.type === "toolCall" && part.id === "pressure-read",
          )
        )
          return {
            message: {
              ...message,
              usage: { ...message.usage, input: 140000, totalTokens: 140000 },
            },
          };
      });
    },
  });
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
        { id: "pressure-read" },
      ),
      { stopReason: "toolUse" },
    ),
    fauxAssistantMessage("Done."),
  ]);
  await h.session.prompt("Find the decision.");
  assert.match(JSON.stringify(observed.at(-1)), /context-pressure/);
  assert.match(JSON.stringify(observed.at(-1)), /used-tokens/);
  assert.equal(
    h.manager
      .getBranch()
      .some(
        (entry) =>
          entry.type === "custom_message" &&
          entry.customType === "ctx-pressure",
      ),
    false,
  );
});

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
    read: async (params: Record<string, unknown>) => {
      const validated = validateToolArguments(
        tool!,
        fauxToolCall("recall", params),
      );
      return tool!.execute("test", validated, undefined, undefined, context);
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

test("recall searches and exactly pages shared trace entries after compaction", async () => {
  const h = recallHarness();
  const original = user(h.manager, `needle ${"x".repeat(24000)} end-marker`);
  const tail = user(h.manager, "Current tail");
  h.manager.appendCompaction(observation, tail, 40000);
  const search = await h.read({
    action: "search",
    target: "needle",
    offset: 0,
    scope: "lineage",
  });
  assert.match(resultText(search), new RegExp(original));
  assert.match(
    resultText(search),
    new RegExp(h.manager.getEntry(original)!.timestamp),
  );
  const first = await h.read({
    action: "read",
    target: original,
    offset: 0,
    scope: "lineage",
  });
  assert.match(resultText(first), /Continue: recall/);
  const second = await h.read({
    action: "read",
    target: original,
    offset: 12000,
    scope: "lineage",
  });
  const third = await h.read({
    action: "read",
    target: original,
    offset: 24000,
    scope: "lineage",
  });
  assert.match(resultText(second) + resultText(third), /end-marker/);
  assert.ok(compileTraceEntry(h.manager.getEntry(original)!).length > 0);
  assert.deepEqual(
    (await readdir(directory)).filter((name) => name.startsWith(".pi")),
    [],
  );
});
