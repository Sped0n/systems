import assert from "node:assert/strict";
import { mkdtemp, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
	fauxAssistantMessage, fauxProvider, fauxToolCall, InMemoryCredentialStore, InMemoryModelsStore,
	type Context, type Message,
} from "@earendil-works/pi-ai";
import {
	createAgentSession, DefaultResourceLoader, ModelRuntime, SessionManager, SettingsManager,
	type ExtensionFactory,
} from "@earendil-works/pi-coding-agent";

import aacExtension from "./index.ts";
import { AAC_STATE_TYPE, aacMessageTokens, buildAacView, readAacWindow } from "./context.ts";
import { recallAacHistory } from "./recall.ts";

let timestamp = 1;
const user = (text: string): Message => ({ role: "user", content: text, timestamp: timestamp++ });
const assistant = (text: string) => fauxAssistantMessage(text, { timestamp: timestamp++ });
const serialized = (value: unknown) => JSON.stringify(value);

async function createTestSession(
	directory: string, manager: SessionManager, extensions: ExtensionFactory[] = [aacExtension],
) {
	const faux = fauxProvider({ provider: "aac-test", models: [{ id: "test", contextWindow: 128_000, maxTokens: 4_096 }] });
	const runtime = await ModelRuntime.create({
		credentials: new InMemoryCredentialStore(), modelsStore: new InMemoryModelsStore(),
		modelsPath: null, refreshOnCreate: false,
	});
	runtime.registerNativeProvider(faux.provider);
	const settings = SettingsManager.inMemory({ compaction: { enabled: true, keepRecentTokens: 512, reserveTokens: 4_096 } });
	const loader = new DefaultResourceLoader({
		cwd: directory, agentDir: directory, settingsManager: settings,
		noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true,
		noContextFiles: true, systemPrompt: "Complete the user's task.", extensionFactories: extensions,
	});
	await loader.reload();
	const { session } = await createAgentSession({
		cwd: directory, agentDir: directory, resourceLoader: loader, sessionManager: manager,
		settingsManager: settings, modelRuntime: runtime, model: faux.getModel(), noTools: "builtin",
	});
	const errors: string[] = [];
	await session.bindExtensions({ onError: (error) => errors.push(error.error) });
	return { session, faux, errors };
}

test("checkpoint rollover continues the real agent loop and survives resume and reload", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-test-"));
	try {
		const manager = SessionManager.create(directory, path.join(directory, "sessions"));
		const evidenceId = manager.appendMessage(user("original evidence: rollback fails on schema X"));
		manager.appendMessage(assistant("old investigation transcript"));
		const { session, faux, errors } = await createTestSession(directory, manager);
		const requests: Context[] = [];
		try {
			faux.setResponses([
				fauxAssistantMessage(fauxToolCall("aac_checkpoint", {
					checkpoint: "Use schema Y because X breaks rollback. Next: verify migration.", sourceIds: [evidenceId],
				})),
				(context) => {
					requests.push(context);
					return fauxAssistantMessage("Migration verified.");
				},
			]);
			await session.prompt("Continue the migration.");
			assert.match(serialized(requests[0]), /Use schema Y/);
			assert.doesNotMatch(serialized(requests[0]), /old investigation transcript/);
			assert.ok(!requests[0].messages.some((message) => message.role === "toolResult"));
			assert.equal(faux.state.callCount, 2);
			assert.deepEqual(errors, []);
			assert.match(readAacWindow(manager.getBranch())!.checkpoint, /schema Y/);
			assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: evidenceId }), /rollback fails/);
			await session.reload();
			faux.setResponses([(context) => {
				requests.push(context);
				return fauxAssistantMessage("Reload retained continuity.");
			}]);
			await session.prompt("Check after reload.");
			assert.match(serialized(requests[1]), /schema Y/);
			assert.doesNotMatch(serialized(requests[1]), /old investigation transcript/);
		} finally { session.dispose(); }

		const restored = SessionManager.open(manager.getSessionFile()!);
		const resumed = await createTestSession(directory, restored);
		try {
			resumed.faux.setResponses([(context) => {
				requests.push(context);
				return fauxAssistantMessage("Resumed successfully.");
			}]);
			await resumed.session.prompt("Resume work.");
			assert.match(serialized(requests[2]), /schema Y/);
			assert.match(serialized(requests[2]), /Migration verified/);
			assert.doesNotMatch(serialized(requests[2]), /old investigation transcript/);
			assert.equal(resumed.faux.state.callCount, 1);
			assert.deepEqual(resumed.errors, []);
		} finally { resumed.session.dispose(); }
		assert.ok(!(await readdir(directory)).includes(".pi"));
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("branch navigation and forks restore only their own checkpoint; recall expands other branches explicitly", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-branch-"));
	try {
		const manager = SessionManager.create(directory, directory);
		const root = manager.appendMessage(user("shared goal"));
		manager.appendMessage(assistant("shared response"));
		const abandoned = manager.appendMessage(user("abandoned secret investigation"));
		manager.appendCustomEntry(AAC_STATE_TYPE, {
			version: 1, afterId: abandoned, checkpoint: "abandoned decision", sourceIds: [], stale: false,
		});
		const abandonedLeaf = manager.getLeafId()!;
		manager.branch(root);
		manager.appendMessage(user("current investigation"));
		assert.equal(readAacWindow(manager.getBranch()), undefined);
		assert.doesNotMatch(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: abandoned }), /secret investigation/);
		assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: abandoned, scope: "session" }), /other-branch.*\n.*secret investigation/);
		manager.branch(abandonedLeaf);
		assert.equal(readAacWindow(manager.getBranch())!.checkpoint, "abandoned decision");
		const forkPath = manager.createBranchedSession(abandonedLeaf)!;
		const fork = SessionManager.open(forkPath);
		assert.equal(readAacWindow(fork.getBranch())!.checkpoint, "abandoned decision");
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("fallback is bounded across repeated windows and preserves original evidence", () => {
	const manager = SessionManager.inMemory();
	const request = manager.appendMessage(user("Keep the safety requirement."));
	manager.appendCustomEntry(AAC_STATE_TYPE, {
		version: 1, afterId: request, checkpoint: "Do not overwrite the production database.", sourceIds: [request], stale: false,
	});
	for (let round = 0; round < 3; round++) {
		for (let index = 0; index < 12; index++) manager.appendMessage(assistant(`round-${round}-${index} ${"evidence ".repeat(120)}`));
		const branch = manager.getBranch();
		const result = buildAacView(manager.buildSessionContext().messages, branch, 4_000);
		assert.ok(result.window?.stale);
		assert.ok(result.messages.reduce((sum, message) => sum + aacMessageTokens(message), 0) <= 4_000);
		assert.match(serialized(result.messages), /safety requirement/);
		assert.match(serialized(result.messages), /production database/);
		manager.appendCustomEntry(AAC_STATE_TYPE, result.window);
	}
	assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { query: "round-0-0" }), /round-0-0/);
});

test("oversized parallel results are projected as recall references without losing call/result pairing", () => {
	const manager = SessionManager.inMemory();
	manager.appendMessage(user("Investigate both files."));
	manager.appendMessage(fauxAssistantMessage([
		fauxToolCall("read", { path: "a" }, { id: "call-a" }),
		fauxToolCall("read", { path: "b" }, { id: "call-b" }),
	], { timestamp: timestamp++ }));
	const ids = ["a", "b"].map((name) => manager.appendMessage({
		role: "toolResult", toolCallId: `call-${name}`, toolName: "read", isError: false,
		content: [{ type: "text", text: `${name}-original ${"x".repeat(30_000)}` }], timestamp: timestamp++,
	}));
	const original = serialized(manager.getEntries());
	const result = buildAacView(manager.buildSessionContext().messages, manager.getBranch(), 4_000);
	assert.equal(result.messages.filter((message) => message.role === "toolResult").length, 2);
	for (const id of ids) assert.match(serialized(result.messages), new RegExp(id));
	assert.equal(serialized(manager.getEntries()), original);
	assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: ids[0], offset: 6_000 }), /offset=12000/);
});

test("interrupted tool batches cannot produce orphaned results or missing tool responses", () => {
	const manager = SessionManager.inMemory();
	manager.appendMessage(user("Continue safely."));
	manager.appendMessage(fauxAssistantMessage([
		fauxToolCall("read", {}, { id: "a" }), fauxToolCall("read", {}, { id: "b" }),
	], { timestamp: timestamp++ }));
	manager.appendMessage({ role: "toolResult", toolCallId: "a", toolName: "read", content: [], isError: false, timestamp: timestamp++ });
	const result = buildAacView(manager.buildSessionContext().messages, manager.getBranch(), 4_000);
	assert.ok(result.messages.every((message) => message.role !== "toolResult" && message.role !== "assistant"));
});

test("an oversized latest user request is rejected rather than silently truncated", () => {
	const manager = SessionManager.inMemory();
	manager.appendMessage(user("critical instructions ".repeat(5_000)));
	assert.throws(() => buildAacView(manager.buildSessionContext().messages, manager.getBranch(), 4_000), /Shorten the request/);
});

test("invalid persisted AAC state aborts rather than falling through the fail-open context hook", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-invalid-"));
	try {
		const manager = SessionManager.inMemory(directory);
		manager.appendCustomEntry(AAC_STATE_TYPE, { version: 99 });
		const { session, faux, errors } = await createTestSession(directory, manager);
		try {
			faux.setResponses([fauxAssistantMessage("This must not run.")]);
			await session.prompt("Continue.");
			assert.equal(faux.state.callCount, 0);
			assert.deepEqual(errors, []);
		} finally { session.dispose(); }
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("manual and threshold compaction never invoke a summarizer", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-compact-"));
	try {
		const manager = SessionManager.inMemory(directory);
		manager.appendMessage(user("task evidence ".repeat(1_000)));
		manager.appendMessage(assistant("Prior work."));
		manager.appendMessage(user("Next step."));
		manager.appendMessage(assistant("Recent investigation. ".repeat(300)));
		const { session, faux, errors } = await createTestSession(directory, manager);
		try {
			await assert.rejects(session.compact(), /cancelled/i);
			assert.equal(faux.state.callCount, 0);
			const done = fauxAssistantMessage("Task complete.");
			done.usage.input = 125_000;
			done.usage.totalTokens = 125_000;
			faux.setResponses([done]);
			await session.prompt("Finish.");
			assert.equal(faux.state.callCount, 1);
			assert.equal(manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
			assert.deepEqual(errors, []);
		} finally { session.dispose(); }
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("checkpoint calls mixed with other tools cannot advance the window", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-parallel-"));
	try {
		const manager = SessionManager.inMemory(directory);
		const { session, faux, errors } = await createTestSession(directory, manager);
		const requests: Context[] = [];
		try {
			faux.setResponses([
				fauxAssistantMessage([
					fauxToolCall("aac_checkpoint", { checkpoint: "premature notes" }),
					fauxToolCall("aac_recall", {}),
				]),
				(context) => {
					requests.push(context);
					return fauxAssistantMessage("Will checkpoint after the batch.");
				},
			]);
			await session.prompt("Investigate first.");
			assert.match(serialized(requests[0]), /Call aac_checkpoint alone/);
			assert.equal(readAacWindow(manager.getBranch()), undefined);
			assert.deepEqual(errors, []);
		} finally { session.dispose(); }
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("recall pagination searches beyond the first excerpt and cannot expand sibling IDs by default", () => {
	const manager = SessionManager.inMemory();
	const root = manager.appendMessage(user("shared goal"));
	for (let index = 0; index < 8; index++) manager.appendMessage(assistant(`${"prefix ".repeat(500)} needle-${index}`));
	const first = recallAacHistory(manager.getEntries(), manager.getBranch(), { query: "needle" });
	assert.match(first, /needle-7/);
	assert.match(first, /offset=5/);
	const second = recallAacHistory(manager.getEntries(), manager.getBranch(), { query: "needle", offset: 5 });
	assert.match(second, /needle-0/);
	assert.doesNotMatch(second, /needle-7/);
	const otherId = manager.getLeafId()!;
	manager.branch(root);
	manager.appendMessage(user("new branch"));
	assert.doesNotMatch(recallAacHistory(manager.getEntries(), manager.getBranch(), { query: "needle" }), /needle-/);
	assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: otherId, scope: "session" }), /other-branch/);
});

test("cancelled overflow does not force a rollover on the next request", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-cancel-"));
	try {
		const manager = SessionManager.inMemory(directory);
		manager.appendMessage(user("original task"));
		for (let index = 0; index < 8; index++) manager.appendMessage(assistant(`retained-evidence-${index} ${"x".repeat(1_500)}`));
		let cancelCompaction = () => {};
		const cancelExtension: ExtensionFactory = (pi) => {
			pi.on("session_before_compact", (event) => {
				if (event.reason === "overflow") cancelCompaction();
			});
		};
		const { session, faux, errors } = await createTestSession(directory, manager, [aacExtension, cancelExtension]);
		cancelCompaction = () => session.abortCompaction();
		try {
			faux.setResponses([fauxAssistantMessage("", {
				stopReason: "error", errorMessage: "maximum context length exceeded",
			})]);
			await session.prompt("Continue.");
			assert.equal(faux.state.callCount, 1);
			const requests: Context[] = [];
			faux.setResponses([(context) => {
				requests.push(context);
				return fauxAssistantMessage("Continued after cancellation.");
			}]);
			await session.prompt("Try again.");
			assert.match(serialized(requests[0]), /retained-evidence-0/);
			assert.equal(readAacWindow(manager.getBranch()), undefined);
			assert.equal(manager.getBranch().filter((entry) => entry.type === "compaction").length, 0);
			assert.deepEqual(errors, []);
		} finally { session.dispose(); }
	} finally { await rm(directory, { recursive: true, force: true }); }
});

test("pressure reminders are included in the bounded view's reported token count", () => {
	const manager = SessionManager.inMemory();
	manager.appendMessage(user("task"));
	manager.appendMessage(assistant("investigation ".repeat(250)));
	const result = buildAacView(manager.buildSessionContext().messages, manager.getBranch(), 2_500);
	const actual = result.messages.reduce((sum, message) => sum + aacMessageTokens(message), 0);
	assert.match(serialized(result.messages), /nearing its limit/);
	assert.equal(result.tokens, actual);
	assert.ok(actual <= 2_500);
});

test("state and native summaries are not exposed as original recall evidence", () => {
	const manager = SessionManager.inMemory();
	const source = manager.appendMessage(user("original migration evidence"));
	const summaryId = manager.appendCompaction("derived checkpoint", source, 100);
	const stateId = manager.appendCustomEntry(AAC_STATE_TYPE, {
		version: 1, afterId: source, checkpoint: "carryover", sourceIds: [summaryId], stale: false,
	});
	assert.throws(() => readAacWindow(manager.getBranch()), /original evidence/);
	for (const id of [summaryId, stateId]) {
		assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id }), /not found/);
	}
	assert.match(recallAacHistory(manager.getEntries(), manager.getBranch(), { id: source }), /original migration evidence/);
});

test("overflow uses exactly one native retry marker and never asks the model to summarize", async () => {
	const directory = await mkdtemp(path.join(tmpdir(), "aac-overflow-"));
	try {
		const manager = SessionManager.inMemory(directory);
		manager.appendMessage(user("original task"));
		for (let index = 0; index < 8; index++) manager.appendMessage(assistant(`evidence-${index} ${"x".repeat(1_500)}`));
		const { session, faux, errors } = await createTestSession(directory, manager);
		try {
			const requests: Context[] = [];
			faux.setResponses([
				(context) => {
					requests.push(context);
					return fauxAssistantMessage("", { stopReason: "error", errorMessage: "maximum context length exceeded" });
				},
				(context) => { requests.push(context); return fauxAssistantMessage("Recovered."); },
			]);
			await session.prompt("Continue the task.");
			assert.equal(faux.state.callCount, 2);
			assert.ok(serialized(requests[1]).length < serialized(requests[0]).length);
			assert.equal(manager.getBranch().filter((entry) => entry.type === "compaction").length, 1);
			assert.ok(readAacWindow(manager.getBranch())?.stale);
			assert.deepEqual(errors, []);
		} finally { session.dispose(); }
	} finally { await rm(directory, { recursive: true, force: true }); }
});
