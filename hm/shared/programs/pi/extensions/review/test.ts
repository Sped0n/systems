import assert from "node:assert/strict";
import test from "node:test";

import type { Message } from "@earendil-works/pi-ai";
import { SessionManager, type ExtensionAPI, type ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

import reviewExtension, {
	boundReviewBrief,
	buildReviewConversationBrief,
	buildReviewPrompt,
	filterReviewAutocompleteItems,
	findLatestReviewReport,
} from "./index.ts";

function textMessage(
	role: "user" | "assistant",
	text: string,
	stopReason: "stop" | "aborted" = "stop",
): Message {
	if (role === "user") {
		return { role, content: [{ type: "text", text }], timestamp: 1 };
	}
	return {
		role,
		content: [{ type: "text", text }],
		provider: "test",
		model: "test",
		api: "openai-responses",
		usage: {
			input: 0,
			output: 0,
			cacheRead: 0,
			cacheWrite: 0,
			totalTokens: 0,
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
		},
		stopReason,
		timestamp: 1,
	};
}

test("boundReviewBrief keeps the beginning and recent context within its limit", () => {
	const brief = `first:${"a".repeat(20_000)}:middle:${"b".repeat(20_000)}:last`;
	const result = boundReviewBrief(brief);

	assert.equal(result.length, 30_000);
	assert.match(result, /^first:/u);
	assert.match(result, /Earlier conversation omitted/u);
	assert.match(result, /:last$/u);
});

test("buildReviewConversationBrief includes dialogue and excludes tool results", () => {
	const messages = [
		textMessage("user", "preserve cancellation semantics"),
		{
			role: "toolResult",
			toolCallId: "1",
			toolName: "read",
			content: [{ type: "text", text: "large output" }],
			isError: false,
			timestamp: 1,
		},
		textMessage("assistant", "implemented an explicit state transition"),
	] as Message[];

	const result = buildReviewConversationBrief(messages);
	assert.match(result, /User: preserve cancellation semantics/u);
	assert.match(result, /Assistant: implemented an explicit state transition/u);
	assert.doesNotMatch(result, /large output/u);
});

test("buildReviewPrompt defaults to uncommitted changes", () => {
	const prompt = buildReviewPrompt("", "User: keep behavior stable");

	assert.match(prompt, /Review all staged, unstaged, and untracked changes\./u);
	assert.match(prompt, /<current_session_context>\nUser: keep behavior stable/u);
	assert.match(prompt, /No actionable findings\./u);
	assert.match(prompt, /canonical owner/u);
	assert.match(prompt, /caller's perspective/u);
	assert.match(prompt, /rg --no-config/u);
	assert.doesNotMatch(prompt, /\{\{(?:CURRENT_SESSION_CONTEXT|REVIEW_INSTRUCTIONS)\}\}/u);
	assert.doesNotMatch(prompt, /git-read/u);
});

test("buildReviewPrompt preserves free-form scope and focus instructions", () => {
	const instructions = "Review main...HEAD under src/auth, focusing on authorization.";
	assert.match(buildReviewPrompt(instructions, ""), new RegExp(instructions.replaceAll(".", "\\."), "u"));
});

test("filterReviewAutocompleteItems exposes end-review only during review", () => {
	const items = [{ value: "review" }, { value: "end-review" }];
	assert.deepEqual(filterReviewAutocompleteItems(items, false), [{ value: "review" }]);
	assert.deepEqual(filterReviewAutocompleteItems(items, true), items);
});

test("review preserves the selected model and AAC tools across entry, restoration, and return", async () => {
	const manager = SessionManager.inMemory();
	manager.appendMessage(textMessage("user", "Review context"));
	manager.appendMessage(textMessage("assistant", "Implementation finished"));
	type Command = Parameters<ExtensionAPI["registerCommand"]>[1];
	const commands = new Map<string, Command>();
	const hooks = new Map<string, (_event: unknown, ctx: ExtensionCommandContext) => void>();
	const previousTools = ["read", "bash", "edit", "aac_checkpoint", "aac_recall"];
	let activeTools = previousTools;
	const pi = {
		registerCommand: (name: string, command: Command) => commands.set(name, command),
		registerMessageRenderer() {},
		on: (name: string, handler: (_event: unknown, ctx: ExtensionCommandContext) => void) => hooks.set(name, handler),
		getActiveTools: () => activeTools,
		setActiveTools: (tools: string[]) => { activeTools = tools; },
		setModel: () => { throw new Error("Review must retain the selected model"); },
		exec: async () => ({ code: 0, stdout: "true", stderr: "" }),
		appendEntry: (type: string, data: unknown) => manager.appendCustomEntry(type, data),
		sendUserMessage() {},
		sendMessage() {},
	} as unknown as ExtensionAPI;
	const ctx = {
		cwd: process.cwd(), sessionManager: manager, model: { id: "chosen-model" },
		isIdle: () => true,
		navigateTree: async (id: string) => { manager.branch(id); return { cancelled: false }; },
		ui: { setWidget() {}, setEditorText() {}, addAutocompleteProvider() {}, notify() {} },
	} as unknown as ExtensionCommandContext;
	reviewExtension(pi);
	try {
		await commands.get("review")!.handler("Review main...HEAD", ctx);
		assert.ok(activeTools.includes("aac_checkpoint") && activeTools.includes("aac_recall"));
		assert.ok(!activeTools.includes("edit"));
		hooks.get("session_start")!({}, ctx);
		assert.ok(activeTools.includes("aac_checkpoint") && activeTools.includes("aac_recall"));
		assert.equal(ctx.model!.id, "chosen-model");
		manager.appendMessage(textMessage("assistant", "No actionable findings."));
		await commands.get("end-review")!.handler("", ctx);
		assert.deepEqual(activeTools, previousTools);
	} finally { hooks.get("session_shutdown")!({}, ctx); }
});

test("findLatestReviewReport returns the latest assistant text", () => {
	assert.equal(
		findLatestReviewReport([
			textMessage("assistant", "initial finding"),
			textMessage("user", "verify that"),
			textMessage("assistant", "verified final report"),
		]),
		"verified final report",
	);
	assert.equal(findLatestReviewReport([textMessage("user", "no report yet")]), "");
	assert.equal(
		findLatestReviewReport([
			textMessage("assistant", "older complete report"),
			textMessage("assistant", "partial final report", "aborted"),
		]),
		"",
	);
});
