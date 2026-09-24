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
  renderObserverTrace,
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
  const low = contextPressure(59, 110, 10)!;
  assert.equal(low.level, "low");
  assert.equal(renderContextPressure(low), "");
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
  assert.equal(contextPressure(NaN, 110, 10), undefined);
  assert.equal(contextPressure(10, 110, NaN), undefined);
});

test("observer preserves user directives omitted from a tool-heavy general trace", () => {
  const manager = SessionManager.inMemory();
  manager.appendMessage(fauxAssistantMessage(`before ${"x".repeat(50_000)}`));
  const directive = user(manager, "Never place build output in tmpfs.");
  manager.appendMessage(fauxAssistantMessage(`after ${"y".repeat(50_000)}`));
  const prompt = buildObservationPrompt({
    userEntries: manager
      .getBranch()
      .filter(
        (entry) => entry.type === "message" && entry.message.role === "user",
      ),
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
    userEntries: manager.getBranch(),
    previousObservation: "## Current task\nOld task",
    compactedEntries: manager.getBranch().slice(0, split),
    retainedEntries: manager.getBranch().slice(split),
    focus: "Focus on blockers",
  });
  assert.match(prompt, /^<conversation>/);
  assert.match(prompt, /<user-directive-evidence>[\s\S]*Old requirement/);
  assert.match(
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
  assert.match(prompt, /## Active instructions/);
  assert.match(prompt, /## Decisions and current state/);
  assert.match(prompt, /task or phase change alone does not revoke them/);
});

test("observer projection preserves conversation coverage before tool bodies", () => {
  const manager = SessionManager.inMemory();
  for (let index = 0; index < 30; index++) {
    toolResult(manager, `read-${index}`, "read", "large payload ".repeat(5000));
    if (index === 15)
      manager.appendMessage(
        fauxAssistantMessage("The defect is in transport.ts, not storage.ts."),
      );
  }
  const failure = toolResult(
    manager,
    "failure",
    "bash",
    `compiler preamble\n${"detail ".repeat(5000)}\nfatal: transport symbol missing`,
    true,
  );
  const rendered = renderObserverTrace(manager.getBranch(), 4000);
  assert.match(rendered, /The defect is in transport.ts, not storage.ts/);
  assert.doesNotMatch(rendered, /omitted to fit the observer input/);
  assert.match(rendered, /bash error/);
  assert.match(rendered, /fatal: transport symbol missing/);
  assert.match(rendered, new RegExp(`read original entry ${failure}`));
  assert.ok(rendered.length <= 4000 * 4);
});

test("original user evidence is not silently clipped at the old directive budget", () => {
  const manager = SessionManager.inMemory();
  user(manager, `First requirement. ${"original intent ".repeat(2500)}`);
  const middle = user(manager, "Never modify vendor sources.");
  user(manager, `Latest requirement. ${"original intent ".repeat(2500)}`);
  const prompt = buildObservationPrompt({
    userEntries: manager.getBranch(),
    compactedEntries: [],
    retainedEntries: [],
  });
  assert.match(prompt, new RegExp(`entry ${middle}`));
  assert.match(prompt, /Never modify vendor sources/);
  assert.doesNotMatch(prompt, /omitted to fit/);
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
        assert.equal(getCurrentTools(context.messages).length, 0);
        const systemPrompt = getCurrentSystemPrompt(context.messages);
        assert.match(systemPrompt, /Do NOT continue the conversation/);
        assert.match(systemPrompt, /ONLY output/);
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

for (const scenario of ["fresh", "new work", "high pressure"] as const) {
  test(
    `tool compaction eligibility: ${scenario}`,
    { timeout: 15000 },
    async (t) => {
      const h = await runtime(t, {
        extraFactory: (pi) => {
          pi.on("message_end", (event) => {
            if (
              event.message.role !== "assistant" ||
              !event.message.content.some(
                (part) => part.type === "toolCall" && part.name === "compact",
              )
            )
              return;
            const tokens = scenario === "high pressure" ? 150000 : 15000;
            return {
              message: {
                ...event.message,
                usage: {
                  ...event.message.usage,
                  input: tokens,
                  totalTokens: tokens,
                },
              },
            };
          });
        },
      });
      h.manager.appendCompaction(observation, h.oldId!, 100000);
      if (scenario === "new work")
        h.manager.appendMessage(
          fauxAssistantMessage(
            "Investigated the new architecture and identified a concrete defect.",
          ),
        );
      h.session.refreshContext();
      h.faux.setResponses([
        fauxAssistantMessage(
          fauxToolCall("compact", {}, { id: "eligibility" }),
          { stopReason: "toolUse" },
        ),
        ...(scenario === "fresh"
          ? [
              fauxAssistantMessage(
                fauxToolCall("compact", {}, { id: "retry" }),
                { stopReason: "toolUse" },
              ),
            ]
          : [fauxAssistantMessage(observation)]),
        fauxAssistantMessage("Discuss the new architecture."),
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
                    part.text === "Discuss the new architecture.",
                ),
            )
        )
          finished.resolve();
      });
      await h.session.prompt("Discuss how we can simplify the architecture.");
      await finished.promise;
      await h.session.waitForIdle();
      assert.deepEqual(h.errors, []);
      assert.equal(
        h.manager.getBranch().filter((entry) => entry.type === "compaction")
          .length,
        scenario === "fresh" ? 1 : 2,
      );
      assert.equal(h.faux.state.callCount, 3);
      if (scenario === "fresh") {
        assert.equal(
          h.manager
            .getBranch()
            .filter(
              (entry) =>
                entry.type === "custom_message" &&
                entry.customType === COMPACTION_CONTINUATION_TYPE,
            ).length,
          0,
        );
        // Manual compaction remains an explicit override of tool eligibility.
        h.faux.setResponses([fauxAssistantMessage(observation)]);
        await h.session.compact();
        assert.equal(
          h.manager.getBranch().filter((entry) => entry.type === "compaction")
            .length,
          2,
        );
      }
    },
  );
}

for (const mode of ["steer", "followUp"] as const) {
  test(
    `queued ${mode} input resumes tool compaction without a competing continuation`,
    { timeout: 15000 },
    async (t) => {
      const queuedText = "New instruction: leave vendor sources untouched.";
      const competingContinuation = Promise.withResolvers<void>();
      t.after(() => competingContinuation.resolve());
      const h = await runtime(t, {
        extraFactory: (pi) => {
          pi.on("before_agent_start", async (event) => {
            if (event.prompt === queuedText) {
              // Hold preflight after its idle check across the compaction callback.
              // This exposes the race even with a fast, local test provider.
              await new Promise<void>((resolve) => setImmediate(resolve));
            }
          });
        },
      });
      h.faux.setResponses([
        fauxAssistantMessage(
          fauxToolCall("compact", {}, { id: "compact-queued" }),
          { stopReason: "toolUse" },
        ),
        fauxAssistantMessage(observation),
        async (context) => {
          if (!JSON.stringify(context.messages).includes(queuedText))
            await competingContinuation.promise;
          return fauxAssistantMessage("Acknowledged the new instruction.");
        },
      ]);
      const sent = Promise.withResolvers<void>();
      const queueErrors: unknown[] = [];
      h.session.subscribe((event) => {
        if (event.type !== "compaction_end" || event.aborted) return;
        // Mirror InteractiveMode.flushCompactionQueue: input is held outside the
        // agent queue during compaction, then prompt preflight starts at its end.
        void h.session.prompt(queuedText, { streamingBehavior: mode }).then(
          () => sent.resolve(),
          (error) => {
            queueErrors.push(error);
            sent.resolve();
          },
        );
      });
      await h.session.prompt("Continue the work.");
      await sent.promise;
      competingContinuation.resolve();
      await h.session.waitForIdle();
      assert.deepEqual(queueErrors, []);
      assert.deepEqual(h.errors, []);
      const entries = h.manager.getBranch();
      assert.equal(
        entries.filter((entry) => entry.type === "compaction").length,
        1,
      );
      assert.equal(
        entries.filter(
          (entry) =>
            entry.type === "message" &&
            entry.message.role === "user" &&
            JSON.stringify(entry.message.content).includes(queuedText),
        ).length,
        1,
      );
      assert.equal(
        entries.filter(
          (entry) =>
            entry.type === "custom_message" &&
            entry.customType === COMPACTION_CONTINUATION_TYPE,
        ).length,
        0,
      );
      assert.equal(h.faux.state.callCount, 3);
    },
  );
}

test("canonical context edits survive ctx projection without rewriting recall history", async (t) => {
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
  await h.session.prompt("Continue with the edited context.");
  assert.doesNotMatch(
    request,
    /Omit this from provider context|Original wording retained in history/,
  );
  assert.match(request, /Replacement provider wording/);
  const history = JSON.stringify(compileTrace(h.manager.getBranch()));
  assert.match(history, /Omit this from provider context/);
  assert.match(history, /Original wording retained in history/);
  assert.deepEqual(h.errors, []);
});

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

test("compaction recovers original intent across old observations on the active lineage", async (t) => {
  const h = await runtime(t, { empty: true });
  const directive = user(h.manager, "Never modify vendor sources.");
  user(h.manager, "Discarded branch: modifying vendor sources is allowed.");
  h.manager.branch(directive);
  const genuineContinuation = user(h.manager, COMPACTION_CONTINUATION);
  const synthetic = h.manager.appendCustomMessageEntry(
    COMPACTION_CONTINUATION_TYPE,
    COMPACTION_CONTINUATION,
    false,
  );
  const kept = seed(h.manager);
  h.manager.appendCompaction(
    "## Current task\nLegacy checkpoint with the prohibition forgotten.",
    kept,
    20000,
    { compactor: "ctx", readFiles: [], modifiedFiles: [] },
    true,
  );
  const correction = user(
    h.manager,
    "Use a patch outside vendor sources instead.",
  );
  h.faux.setResponses([
    (context) => {
      const prompt = JSON.stringify(context.messages);
      const evidence =
        prompt.match(
          /<user-directive-evidence>([\s\S]*?)<\/user-directive-evidence>/,
        )?.[1] ?? "";
      for (const id of [directive, genuineContinuation, correction])
        assert.match(evidence, new RegExp(`entry ${id}`));
      assert.doesNotMatch(evidence, new RegExp(synthetic));
      assert.doesNotMatch(evidence, /Discarded branch/);
      assert.match(evidence, /Never modify vendor sources/);
      assert.match(prompt, /Legacy checkpoint/);
      return fauxAssistantMessage(observation);
    },
  ]);
  await h.session.compact();
  assert.equal(h.faux.state.callCount, 1);
  assert.equal(
    h.manager.getBranch().filter((entry) => entry.type === "compaction").length,
    2,
  );
});

test("oversized original user evidence cancels compaction without a provider call", async (t) => {
  const h = await runtime(t);
  user(h.manager, "Unabridged requirement. ".repeat(40000));
  const leaf = h.manager.getLeafId();
  await assert.rejects(h.session.compact(), /cancelled|failed/i);
  assert.equal(h.faux.state.callCount, 0);
  assert.equal(h.manager.getLeafId(), leaf);
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
  assert.doesNotMatch(JSON.stringify(observed[0]), /context-pressure/);
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
    read: async (params: JsonObject) => {
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
