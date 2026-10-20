import assert from "node:assert/strict";
import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { after, before, type TestContext } from "node:test";

import {
    fauxAssistantMessage,
    fauxProvider,
    fauxToolCall,
    getCurrentTools,
    InMemoryCredentialStore,
    InMemoryModelsStore,
    validateToolArguments,
    type JsonObject,
} from "@earendil-works/pi-ai";
import { Type } from "typebox";

import {
    createAgentSession,
    createCodemodeExtension,
    estimateTokens,
    DefaultResourceLoader,
    ModelRuntime,
    SessionManager,
    SettingsManager,
    sessionEntryToContextMessages,
    type ExtensionAPI,
    type ExtensionToolContext,
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
            fauxAssistantMessage(
                `Finished ${index}. ${"evidence ".repeat(100)}`,
            ),
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
            settings: {
                enabled: true,
                reserveTokens: 16384,
                keepRecentTokens: 1000,
            },
        },
    };
}
function recallHarness(manager = SessionManager.inMemory()) {
    let tool: ToolDefinition | undefined;
    registerRecall({
        registerTool: (definition: ToolDefinition) => {
            tool = definition;
        },
        registerCommand: () => {},
    } as unknown as ExtensionAPI);
    const context = {
        sessionManager: manager,
    } as unknown as ExtensionToolContext;
    return {
        manager,
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
        codemode?: "on" | "only";
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
    if (options.codemode) {
        settings.applyOverrides({ codemode: { mode: options.codemode } });
    }
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
            ...(options.codemode
                ? [
                      createCodemodeExtension({
                          mode: options.codemode,
                          models: false,
                      }),
                  ]
                : []),
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
        tools: options.codemode
            ? ["recall", "codemode", "nested_probe"]
            : ["recall"],
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
    const replaced = user(manager, "Old provider wording.");
    const kept = user(manager, "Current work.");
    manager.appendCompaction(
        "Invented checkpoint authorization: change everything.",
        kept,
        40000,
    );
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
        /Abandoned branch|Invented checkpoint|Synthetic user mandate|Old provider wording/,
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
            fauxAssistantMessage(
                `Investigation ${index}. ${"work ".repeat(1000)}`,
            ),
        );
        toolResult(
            manager,
            `call-${index}`,
            "read",
            "large result ".repeat(5000),
        );
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

test("unused short-request allowance preserves complete longer instructions across compactions", () => {
    const manager = SessionManager.inMemory();
    const requests = Array.from({ length: 24 }, (_, index) =>
        index === 8 || index === 16
            ? Array.from(
                  { length: 35 },
                  (_, clause) =>
                      `Device ${index}, clause ${clause}: preserve public API compatibility and ask before modifying vendor sources.`,
              ).join("\n")
            : `Inspect device ${index}; report only.`,
    );
    for (const request of requests) {
        user(manager, request);
        manager.appendMessage(
            fauxAssistantMessage("Investigation detail. ".repeat(1000)),
        );
    }
    const tail = user(manager, "Continue inspecting the current failure.");
    const first = buildBrief(eventFor(manager, tail), 32000);
    for (const request of requests) assert.ok(first.includes(request));
    assert.ok(
        estimateTokens({
            role: "compactionSummary",
            summary: first,
            tokensBefore: 40000,
            timestamp: 0,
        }) <= 4000,
    );
    manager.appendCompaction(first, tail, 40000);
    user(manager, "Do not change the API.");
    const secondTail = user(manager, "Continue without widening the scope.");
    const second = buildBrief(eventFor(manager, secondTail), 32000);
    for (const request of requests) assert.ok(second.includes(request));
    assert.match(second, /Do not change the API/);
    assert.equal((second.match(/# Session UI view/g) ?? []).length, 1);
    assert.ok(
        estimateTokens({
            role: "compactionSummary",
            summary: second,
            tokensBefore: 40000,
            timestamp: 0,
        }) <= 4000,
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
        fauxAssistantMessage(
            "Propose creating planned.ts, but wait for approval.",
        ),
    );

    const replacement = call("read", "original.ts", "replaced");
    manager.appendContextEdit(replacement, {
        content: [
            fauxToolCall(
                "read",
                { path: "replacement.ts" },
                { id: "replaced" },
            ),
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
        /original.ts|Modified:|Created:|permission denied/,
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
        assert.equal(
            full.text.slice(block.offset, Number(match[3])),
            block.text,
        );
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
        (message) =>
            message.role === "toolResult" && message.toolCallId === "old",
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
                      {
                          type: "text" as const,
                          text: "replacement".repeat(1000),
                      },
                  ],
              }
            : message,
    );
    assert.deepEqual(maskConsumedToolResults(edited, entries), edited);
});

test("recall recovers paged original text and readable but unsearchable recall echoes after compaction", async () => {
    const h = recallHarness();
    const original = user(h.manager, `needle ${"x".repeat(24000)} end-marker`);
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
    });
    assert.match(resultText(search), new RegExp(original));
    assert.match(resultText(search), /Around: recall/);
    let next: JsonObject | null = {
        action: "read",
        target: original,
        offset: 0,
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
    assert.match(
        resultText(
            await h.read({
                action: "read",
                target: echo,
                offset: 0,
            }),
        ),
        /previous recall evidence/,
    );
    assert.match(
        resultText(
            await h.read({
                action: "search",
                target: "previous recall evidence",
                offset: 0,
            }),
        ),
        /No matching history/,
    );
});

test("UI and adaptive retrieval share exact full-view coordinates and distinguish intent from observation", async () => {
    const h = recallHarness();
    const constraint = user(h.manager, "Keep the existing API.");
    h.manager.appendMessage(
        fauxAssistantMessage(
            [
                { type: "thinking", thinking: "needle private reasoning" },
                {
                    type: "text",
                    text: "I propose needle; not yet verified. 🐕",
                },
                fauxToolCall(
                    "write",
                    {
                        path: "needle.ts",
                        content: "needle payload\nsecond line",
                    },
                    { id: "needle-call" },
                ),
            ],
            { stopReason: "toolUse" },
        ),
    );
    toolResult(
        h.manager,
        "needle-call",
        "write",
        "needle was NOT written",
        true,
    );
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
    });
    const text = resultText(found);
    for (const role of ["thinking", "assistant", "tool_call", "tool_result"])
        assert.ok(text.includes(`[${role}]`));
    assert.doesNotMatch(text, /assistant\+tool_call/);
    for (const args of (found.details as { reads: JsonObject[] }).reads)
        assert.match(
            resultText(await h.read(args)),
            args.target === constraint ? /Keep the existing API/ : /needle/,
        );
});

test("adaptive search bundles recorded calls and observations without changing hit pagination", async () => {
    const h = recallHarness();
    const calls: string[] = [];
    const observations: string[] = [];
    for (let index = 0; index < 6; index++) {
        const id = `runner-${index}`;
        calls.push(
            h.manager.appendMessage(
                fauxAssistantMessage(
                    fauxToolCall(
                        "bash",
                        { command: `requested-fault-${index}` },
                        { id },
                    ),
                    { stopReason: "toolUse" },
                ),
            ),
        );
        observations.push(
            toolResult(
                h.manager,
                id,
                "bash",
                `${"runner output ".repeat(1000)}\nobserved-rejection-${index}: expected denial; received access.`,
                true,
            ),
        );
    }
    const page = await h.read({
        action: "search",
        target: "requested-fault",
        offset: 0,
    });
    const text = resultText(page);
    const details = page.details as {
        total: number;
        next: JsonObject;
        reads: JsonObject[];
    };
    assert.equal(details.total, 6);
    assert.equal(details.next.offset, 5);
    assert.equal(details.reads.length, 10);
    assert.match(text, /related recorded evidence; tool reported error/);
    assert.match(text, /observed-rejection/);
    assert.ok(text.length < 8000);
    for (const [, target, start, end] of text.matchAll(
        /source ([^:;\s]+):(\d+)-(\d+)/g,
    )) {
        const full = recallTraceEntry(
            h.manager.getEntry(target)!,
            h.manager.getBranch(),
        )!.text;
        const quoted = full.slice(Number(start), Number(end));
        assert.ok(quoted.length > 0);
        assert.ok(text.includes(quoted));
        assert.ok(
            resultText(
                await h.read({
                    action: "read",
                    target,
                    offset: Number(start),
                }),
            ).includes(quoted),
        );
    }
    const second = await h.read(details.next);
    assert.equal((second.details as { reads: JsonObject[] }).reads.length, 2);
    const recovered = new Set(
        [
            ...details.reads,
            ...(second.details as { reads: JsonObject[] }).reads,
        ].map((read) => read.target),
    );
    for (const id of [...calls, ...observations]) assert.ok(recovered.has(id));
    const reverse = await h.read({
        action: "search",
        target: "observed-rejection",
        offset: 0,
    });
    assert.match(
        resultText(reverse),
        /\[tool_call\] related recorded evidence/,
    );
    assert.match(resultText(reverse), /requested-fault/);
});

test("adaptive search does not attribute replacements or ambiguous results to recorded calls", async () => {
    const h = recallHarness();
    user(h.manager, "Inspect only.");
    toolResult(h.manager, "shared-id", "read", "orphan-result-before-call");
    const call = h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "read",
                { path: "original-target.ts" },
                { id: "shared-id" },
            ),
            { stopReason: "toolUse" },
        ),
    );
    toolResult(h.manager, "shared-id", "read", "recorded original output");
    const orphan = resultText(
        await h.read({
            action: "search",
            target: "orphan-result-before-call",
            offset: 0,
        }),
    );
    assert.match(orphan, /orphan-result-before-call/);
    assert.doesNotMatch(orphan, /related recorded evidence|original-target/);
    const replacement = h.manager.appendContextEdit(call, {
        content: [
            fauxToolCall(
                "read",
                { path: "replacement-target.ts" },
                { id: "shared-id" },
            ),
        ],
    });
    const edited = resultText(
        await h.read({
            action: "search",
            target: "replacement-target",
            offset: 0,
        }),
    );
    assert.ok(edited.includes(replacement));
    assert.match(edited, /context replacement, not recorded evidence/);
    assert.doesNotMatch(
        edited,
        /related recorded evidence|recorded original output/,
    );
    const original = resultText(
        await h.read({
            action: "search",
            target: "original-target",
            offset: 0,
        }),
    );
    assert.match(original, /related recorded evidence/);
    assert.match(original, /recorded original output/);
    h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "read",
                { path: "duplicate-target.ts" },
                { id: "shared-id" },
            ),
            { stopReason: "toolUse" },
        ),
    );
    toolResult(h.manager, "shared-id", "read", "later output");
    const ambiguous = resultText(
        await h.read({
            action: "search",
            target: "original-target",
            offset: 0,
        }),
    );
    assert.match(ambiguous, /counterpart is ambiguous/);
    assert.doesNotMatch(ambiguous, /related recorded evidence|later output/);
    const ambiguousResult = resultText(
        await h.read({
            action: "search",
            target: "recorded original output",
            offset: 0,
        }),
    );
    assert.match(ambiguousResult, /counterpart is ambiguous/);
    assert.doesNotMatch(ambiguousResult, /related recorded evidence/);
});

test("adaptive ranking surfaces concise observed evidence ahead of matching investigation boilerplate", async () => {
    const h = recallHarness();
    h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "bash",
                { command: "run seeded case" },
                { id: "case" },
            ),
            { stopReason: "toolUse" },
        ),
    );
    const observed = toolResult(
        h.manager,
        "case",
        "bash",
        "document-errors result: Expected denial; received access.",
        true,
    );
    for (let index = 0; index < 12; index++) {
        h.manager.appendMessage(
            fauxAssistantMessage([
                {
                    type: "thinking",
                    thinking: `${"Investigation background. ".repeat(1000)} document-errors Expected result: further inspection needed for item ${index}.`,
                },
            ]),
        );
    }
    const first = await h.read({
        action: "search",
        target: "document-errors Expected result",
        offset: 0,
    });
    const details = first.details as {
        reads: JsonObject[];
        total: number;
        next: JsonObject;
    };
    assert.equal(details.reads[0].target, observed);
    assert.match(resultText(first), /Expected denial; received access/);
    assert.equal(details.total, 13);
    const next = resultText(await h.read(details.next));
    assert.match(next, /\[thinking\] match/);
    assert.match(next, /further inspection needed/);
});

test("adaptive hits retain bounded original user-turn context across branches and canonical edits", async () => {
    const h = await recallHarness();
    const root = user(h.manager, "Inspect recorded evidence only.");
    user(h.manager, "Abandoned turn: destructive operations permitted.");
    h.manager.branch(root);
    const first = user(
        h.manager,
        "Inspect the actuator only. Do not flash or erase persistent storage.",
    );
    const observe = (id: string, command: string) => {
        h.manager.appendMessage(
            fauxAssistantMessage(fauxToolCall("bash", { command }, { id }), {
                stopReason: "toolUse",
            }),
        );
        toolResult(
            h.manager,
            id,
            "bash",
            `episode-needle ${"recorded evidence ".repeat(100)}`,
        );
    };
    for (let index = 0; index < 2; index++)
        observe(`actuator-${index}`, `inspect actuator ${index}`);
    const second = user(
        h.manager,
        "Review the reader trace; still no hardware operations.",
    );
    const replacement = h.manager.appendContextEdit(second, {
        content: "Canonical replacement, not a new recorded user turn.",
    });
    observe("reader", "inspect reader");
    h.manager.appendCompaction(
        "Invented episode-needle authorization.",
        second,
        40000,
    );

    const result = await h.read({
        action: "search",
        target: "episode-needle",
        offset: 0,
    });
    const text = resultText(result);
    const details = result.details as { total: number; reads: JsonObject[] };
    assert.equal(details.total, 3);
    assert.match(text, /Do not flash or erase persistent storage/);
    assert.match(text, /still no hardware operations/);
    assert.match(text, /historical, not approval/);
    assert.doesNotMatch(text, /Abandoned turn|Canonical replacement|Invented/);
    for (const target of [first, second]) {
        const pointers = details.reads.filter((read) => read.target === target);
        assert.equal(
            pointers.length,
            1,
            "deduplicate turn anchors within a page",
        );
        assert.match(resultText(await h.read(pointers[0])), /hardware|flash/);
    }
    assert.ok(!details.reads.some((read) => read.target === replacement));
    const sources = [...text.matchAll(/source ([\w-]+):(\d+)-(\d+)\n/g)];
    assert.equal(sources.length, 8);
    assert.ok(
        sources.reduce(
            (sum, source) => sum + Number(source[3]) - Number(source[2]),
            0,
        ) <=
            details.total * 600,
        "turn excerpts share the existing evidence budget",
    );
    for (const [, target, start, end] of sources) {
        const entry = h.manager.getEntry(target)!;
        const full = recallTraceEntry(entry, h.manager.getBranch())!.text;
        assert.ok(text.includes(full.slice(Number(start), Number(end))));
    }
});

test("literal adaptive search returns usable offsets after Unicode case-expanding text", async () => {
    const h = recallHarness();
    user(h.manager, `${"İ".repeat(1000)} Needle[1].ts`);
    user(h.manager, "needle11ats is not the same literal.");
    const found = await h.read({
        action: "search",
        target: "needle[1].ts",
        offset: 0,
    });
    const details = found.details as { total: number; reads: JsonObject[] };
    assert.equal(details.total, 1);
    assert.match(resultText(await h.read(details.reads[0])), /Needle\[1\]\.ts/);
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
    });
    const text = resultText(around);
    assert.ok(text.indexOf("Propose patching") < text.indexOf("Approved:"));
    assert.ok(text.indexOf("Approved:") < text.indexOf("edit (call patch)"));
    assert.match(text, /Patch applied; tests not yet run/);
    assert.match(text, /Now run the parser tests/);
    h.manager.branch(proposal);
    user(h.manager, "Actually, no edits.");
    await assert.rejects(
        h.read({ action: "read", target: action, offset: 0 }),
        /no recallable text/,
    );
    const active = resultText(
        await h.read({
            action: "around",
            target: proposal,
            offset: 0,
        }),
    );
    assert.doesNotMatch(active, /Approved:|Patch applied/);
    assert.match(active, /Actually, no edits/);
    await assert.rejects(
        h.read({ action: "around", target: action, offset: 0 }),
        /no recallable text/,
    );
    const query = { action: "search", target: "parser.ts", offset: 0 };
    const found = await h.read(query);
    assert.doesNotMatch(resultText(found), /Approved:|Patch applied/);
    const files = await h.read({
        action: "files",
        target: "parser.ts",
        offset: 0,
    });
    assert.equal((files.details as { total: number }).total, 0);
    await assert.rejects(h.read({ ...query, scope: "lineage" }), /scope/);
});

test("file navigation recovers multi-call payloads and failed results across compaction and system entries", async () => {
    const h = recallHarness();
    h.manager.appendMessage({
        role: "system",
        content: "",
        sections: { preamble: "system-loadout-marker" },
        timestamp: 1,
    });
    user(h.manager, "Inspect configuration before editing.");
    const call = h.manager.appendMessage(
        fauxAssistantMessage(
            [
                {
                    type: "thinking",
                    thinking: "Check the existing configuration first.",
                },
                {
                    type: "text",
                    text: "Proposed operations, not proof of completion.",
                },
                fauxToolCall(
                    "write",
                    {
                        path: "src/config[1].ts",
                        content: `${"padding ".repeat(2000)}complete-write-é`,
                    },
                    { id: "file-write" },
                ),
                fauxToolCall(
                    "edit",
                    {
                        file_path: "src/config[1].ts",
                        edits: [{ oldText: "exact-old", newText: "exact-new" }],
                    },
                    { id: "file-edit" },
                ),
                fauxToolCall(
                    "read",
                    { path: "src/other.ts" },
                    { id: "file-read" },
                ),
                fauxToolCall("bash", { command: "echo 'write fabricated.ts'" }),
                fauxToolCall("custom", { path: "not-indexed.ts" }),
            ],
            { stopReason: "toolUse" },
        ),
    );
    h.manager.appendMessage({
        role: "system",
        content: "",
        toolsRemoved: [],
        timestamp: 2,
    });
    const written = toolResult(
        h.manager,
        "file-write",
        "write",
        "Tool reported a completed write.",
    );
    const failed = toolResult(
        h.manager,
        "file-edit",
        "edit",
        "Permission denied; no file changed.",
        true,
    );
    const tail = user(h.manager, "Report the error; do not retry.");
    const params = {
        action: "files",
        target: "CONFIG[1].TS",
        offset: 0,
    };
    const before = await h.read(params);
    h.manager.appendCompaction("Prior summary", tail, 40000);
    const after = await h.read(params);
    assert.deepEqual(after, before);
    const text = resultText(after);
    assert.match(text, /write call .*→ result /);
    assert.match(text, /edit call .*→ error /);
    assert.doesNotMatch(text, /Modified:|Created:|system-loadout-marker/);
    const details = after.details as { total: number; reads: JsonObject[] };
    assert.equal(details.total, 2);
    assert.deepEqual(
        details.reads.map((read) => read.target),
        [call, written, call, failed],
    );
    assert.ok(Number(details.reads[0].offset) > 0);
    const edit = resultText(await h.read(details.reads[2]));
    assert.match(edit, /exact-old.*exact-new/);
    assert.match(
        resultText(await h.read(details.reads[3])),
        /Permission denied/,
    );
    let request: JsonObject | null = details.reads[0];
    let payload = "";
    while (request) {
        const read = await h.read(request);
        payload += resultText(read);
        request = (read.details as { next: JsonObject | null }).next;
    }
    assert.match(payload, /complete-write-é/);
    const all = resultText(await h.read({ ...params, target: "" }));
    assert.match(all, /read call .*→ no recorded result/);
    assert.doesNotMatch(all, /fabricated.ts|not-indexed.ts/);
});

test("file navigation keeps branch evidence and canonical replacements distinct from recorded results", async () => {
    const h = recallHarness();
    const root = user(h.manager, "Inspect only.");
    h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "write",
                { path: "abandoned.ts", content: "abandoned-payload" },
                { id: "branch-call" },
            ),
        ),
    );
    h.manager.branch(root);
    // This orphan result is on another branch, despite its matching tool and ID.
    toolResult(h.manager, "branch-call", "write", "Unrelated branch result.");
    const original = h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "edit",
                { path: "original.ts", oldText: "old", newText: "new" },
                { id: "original-edit" },
            ),
        ),
    );
    const result = toolResult(
        h.manager,
        "original-edit",
        "edit",
        "Recorded edit result.",
    );
    const replacement = h.manager.appendContextEdit(original, {
        content: [
            fauxToolCall(
                "edit",
                {
                    path: "replacement.ts",
                    oldText: "other-old",
                    newText: "other-new",
                },
                { id: "original-edit" },
            ),
        ],
    });
    const params = { action: "files", target: "", offset: 0 };
    const active = resultText(await h.read(params));
    assert.doesNotMatch(active, /abandoned.ts|Unrelated branch result/);
    assert.match(active, /original.ts[\s\S]*edit call .*→ result /);
    assert.match(
        active,
        /replacement.ts[\s\S]*context replacement .*not a recorded call/,
    );
    const edited = await h.read({ ...params, target: "replacement.ts" });
    const reads = (edited.details as { reads: JsonObject[] }).reads;
    assert.equal(reads.length, 1);
    assert.equal(reads[0].target, replacement);
    assert.match(resultText(await h.read(reads[0])), /other-old.*other-new/);
    const abandoned = await h.read({ ...params, target: "abandoned.ts" });
    assert.equal((abandoned.details as { total: number }).total, 0);
    const observed = await h.read({ ...params, target: "original.ts" });
    assert.deepEqual(
        (observed.details as { reads: JsonObject[] }).reads.map(
            (read) => read.target,
        ),
        [original, result],
    );
});

test("file navigation is pageable and does not guess through duplicate call IDs or mismatched tools", async () => {
    const h = recallHarness();
    for (let index = 0; index < 12; index++) {
        h.manager.appendMessage(
            fauxAssistantMessage(
                fauxToolCall(
                    "read",
                    { path: `src/file-${String(index).padStart(2, "0")}.ts` },
                    { id: `read-${index}` },
                ),
            ),
        );
        toolResult(h.manager, `read-${index}`, "read", `Observed ${index}`);
    }
    const params = {
        action: "files",
        target: "src/",
        offset: 0,
    };
    let next: JsonObject | null = params;
    const calls: string[] = [];
    let pages = 0;
    while (next) {
        const page = await h.read(next);
        const details = page.details as {
            total: number;
            reads: JsonObject[];
            next: JsonObject | null;
        };
        assert.equal(details.total, 12);
        assert.ok(details.reads.length <= 10);
        assert.ok(resultText(page).length < 4000);
        for (const read of details.reads) {
            const text = resultText(await h.read(read));
            if (text.includes("] tool_call")) calls.push(String(read.target));
        }
        next = details.next;
        pages++;
    }
    assert.equal(pages, 3);
    assert.equal(new Set(calls).size, 12);
    await assert.rejects(h.read({ ...params, offset: 12 }), /offset/);
    const missing = await h.read({ ...params, target: "does-not-exist" });
    assert.equal((missing.details as { total: number }).total, 0);
    for (const path of ["duplicate-a.ts", "duplicate-b.ts"])
        h.manager.appendMessage(
            fauxAssistantMessage(
                fauxToolCall(
                    "write",
                    { path, content: "payload" },
                    { id: "duplicate" },
                ),
            ),
        );
    toolResult(
        h.manager,
        "duplicate",
        "write",
        "Cannot attribute this result.",
    );
    const ambiguous = await h.read({ ...params, target: "duplicate" });
    assert.match(resultText(ambiguous), /ambiguous result pairing/);
    assert.equal(
        (ambiguous.details as { reads: JsonObject[] }).reads.length,
        2,
    );
    h.manager.appendMessage(
        fauxAssistantMessage(
            fauxToolCall(
                "write",
                { path: "mismatched.ts", content: "payload" },
                { id: "mismatched" },
            ),
        ),
    );
    toolResult(
        h.manager,
        "mismatched",
        "read",
        "Read is not evidence of a write.",
    );
    const mismatched = await h.read({ ...params, target: "mismatched" });
    assert.match(resultText(mismatched), /no recorded result/);
    assert.equal(
        (mismatched.details as { reads: JsonObject[] }).reads.length,
        1,
    );
});

test("recall navigation is bounded and pageable with executable pointers and explicit errors", async () => {
    const h = recallHarness();
    const ids = Array.from({ length: 12 }, (_, index) =>
        user(
            h.manager,
            `${"İ".repeat(300)} compact-marker-${index} ${"x".repeat(2000)}`,
        ),
    );
    for (const action of ["search", "around"]) {
        const page = await h.read({
            action,
            target: action === "search" ? "compact-marker" : ids[2],
            offset: 0,
        });
        const text = resultText(page);
        assert.ok(text.length < 8000);
        if (action === "search") assert.match(text, /compact-marker-11/);
        const pointers = [...text.matchAll(/source ([^:;\s]+):(\d+)-(\d+)/g)];
        assert.equal(pointers.length, 5);
        for (const [, target, start, end] of pointers) {
            const full = recallTraceEntry(
                h.manager.getEntry(target)!,
                h.manager.getBranch(),
            )!.text;
            assert.ok(Number(start) < Number(end));
            assert.ok(Number(end) <= full.length);
            const read = resultText(
                await h.read({ action: "read", target, offset: Number(start) }),
            );
            assert.match(read, /compact-marker/);
        }
        const next = (page.details as { next: JsonObject }).next;
        const second = resultText(await h.read(next));
        assert.match(second, /compact-marker/);
        if (action === "around") {
            assert.match(second, /compact-marker-5/);
            assert.doesNotMatch(second, /compact-marker-4 /);
        }
    }
    const params = { action: "around", target: ids[2], offset: 0 };
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
            }),
        ),
        /refresh-key-4829/,
    );
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
                        (part) =>
                            part.type === "toolCall" &&
                            part.id === "auto-pressure",
                    )
                )
                    return {
                        message: {
                            ...message,
                            usage: {
                                ...message.usage,
                                input: 265000,
                                totalTokens: 265000,
                            },
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
        h.manager.getBranch().filter((entry) => entry.type === "compaction")
            .length,
        1,
    );
    assert.equal(h.faux.state.callCount, 2);
    assert.deepEqual(h.errors, []);
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
    const replaced = user(h.manager, "Original wording retained in history.");
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
    assert.doesNotMatch(request, /Original wording retained in history/);
    assert.match(request, /Replacement provider wording/);
    assert.match(
        JSON.stringify(compileTrace(h.manager.getBranch())),
        /Original wording retained in history/,
    );
    assert.deepEqual(h.errors, []);
});

for (const mode of ["on", "only"] as const) {
    test(`model-only recall stays native and rejects nested execution in codemode ${mode}`, async (t) => {
        const params = {
            action: "search",
            target: "refresh-key-4829",
            offset: 0,
        };
        const h = await runtime(t, {
            codemode: mode,
            extraFactory: (pi) => {
                pi.registerTool({
                    name: "nested_probe",
                    label: "Nested boundary probe",
                    description: "Verify that nested recall is unavailable.",
                    parameters: Type.Object({}),
                    async execute(_id, _args, _signal, _update, ctx) {
                        assert.ok(
                            !ctx.tools.some((tool) => tool.name === "recall"),
                        );
                        const outcome = await ctx.executeTool("recall", params);
                        assert.equal(outcome.isError, true);
                        return {
                            content: [
                                { type: "text", text: "nested-recall-blocked" },
                            ],
                            details: {},
                        };
                    },
                });
            },
        });
        const results: string[] = [];
        h.session.subscribe((event) => {
            if (event.type === "tool_execution_end") {
                results.push(resultText(event.result));
            }
        });
        h.faux.setResponses([
            (context) => {
                const names =
                    getCurrentTools(context.messages)?.map(
                        (tool) => tool.name,
                    ) ?? [];
                assert.ok(names.includes("recall"));
                assert.ok(names.includes("codemode"));
                return fauxAssistantMessage(fauxToolCall("recall", params), {
                    stopReason: "toolUse",
                });
            },
            () => {
                assert.match(results.at(-1)!, /refresh-key-4829/);
                return fauxAssistantMessage(
                    fauxToolCall("codemode", {
                        code: `try { await tools.recall(${JSON.stringify(params)}); text("unexpected-recall-success"); } catch (error) { text("codemode-recall-blocked"); } text(await tools.nested_probe({}));`,
                    }),
                    { stopReason: "toolUse" },
                );
            },
            fauxAssistantMessage("Boundary verified."),
        ]);
        await h.session.prompt(
            "Recover the original requirement and check the nested boundary.",
        );
        assert.match(results.at(-1)!, /codemode-recall-blocked/);
        assert.match(results.at(-1)!, /nested-recall-blocked/);
        assert.doesNotMatch(
            results.at(-1)!,
            /unexpected-recall-success|Script failed/,
        );
        assert.deepEqual(h.errors, []);
    });
}

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
