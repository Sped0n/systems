import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import {
	AAC_CHECKPOINT_CHARACTERS_MAX,
	AAC_STATE_TYPE,
	buildAacView,
	readAacWindow,
	type AacWindow,
} from "./context.ts";
import { isAacRecallEntry, recallAacHistory } from "./recall.ts";

export const AAC_TOOL_NAMES = ["aac_checkpoint", "aac_recall"];

function contextBudget(pi: ExtensionAPI, ctx: ExtensionContext): number {
	if (!ctx.model) throw new Error("AAC requires an active model.");
	const active = new Set(pi.getActiveTools());
	const tools = pi.getAllTools().filter((tool) => active.has(tool.name));
	const fixedTokens = Math.ceil(Buffer.byteLength(ctx.getSystemPrompt() + JSON.stringify(tools)) / 2);
	// Leave room for output, tokenizer variance, provider wrappers, and one reminder.
	const budget = Math.min(64_000, Math.floor(ctx.model.contextWindow * 0.6) - fixedTokens - 1_024);
	if (!Number.isFinite(budget) || budget < 1_024) throw new Error("AAC has no working-context budget. Reduce system instructions/tools or select a larger-context model.");
	return budget;
}

export default function aacExtension(pi: ExtensionAPI): void {
	let overflowRetry = false;

	pi.registerTool(defineTool({
		name: "aac_checkpoint",
		label: "AAC checkpoint",
		description: "Save task continuity and start a fresh working window. Call alone near the context limit, then continue working. Original messages remain available through aac_recall.",
		promptGuidelines: ["When AAC warns about context pressure, call aac_checkpoint alone with the goal, decisions and rationale, constraints, unfinished work, and evidence references. Keep this bookkeeping internal; do not checkpoint every turn."],
		parameters: Type.Object({
			checkpoint: Type.String({ minLength: 1, maxLength: AAC_CHECKPOINT_CHARACTERS_MAX,
				description: "Concise carryover: goal, decisions, constraints, unfinished work, and next actions." }),
			sourceIds: Type.Optional(Type.Array(Type.String({ minLength: 1, maxLength: 64 }), {
				maxItems: 16, description: "Original active-branch entry IDs obtained with aac_recall.",
			})),
		}),
		async execute(toolCallId, input, signal, _onUpdate, ctx) {
			if (signal?.aborted) throw new Error("AAC checkpoint cancelled.");
			const branch = ctx.sessionManager.getBranch();
			const index = branch.findLastIndex((entry) => entry.type === "message" &&
				entry.message.role === "assistant" && entry.message.content.some((part) =>
					part.type === "toolCall" && part.id === toolCallId));
			const entry = branch[index];
			if (entry?.type !== "message" || entry.message.role !== "assistant") {
				throw new Error("AAC cannot locate the checkpoint call in session history.");
			}
			if (entry.message.content.filter((part) => part.type === "toolCall").length !== 1) {
				throw new Error("Call aac_checkpoint alone after the other tools finish.");
			}
			const sourceIds = input.sourceIds ?? [];
			if (!input.checkpoint.trim() || input.checkpoint.length > AAC_CHECKPOINT_CHARACTERS_MAX ||
				sourceIds.length > 16 || sourceIds.some((id) =>
					!branch.some((item) => item.id === id && isAacRecallEntry(item)))) {
				throw new Error("AAC checkpoint must be nonempty, bounded, and cite only existing active-branch IDs.");
			}
			const window: AacWindow = {
				version: 1, afterId: entry.id,
				checkpoint: input.checkpoint.trim(), sourceIds, stale: false,
			};
			// The call is standalone, so its own exchange can be omitted from the next view.
			// Persist before acknowledging; the context hook runs after the tool batch.
			pi.appendEntry(AAC_STATE_TYPE, window);
			return { content: [{ type: "text", text: "AAC checkpoint saved. Continue the task in the new working window; use aac_recall for earlier evidence." }], details: {} };
		},
	}));

	pi.registerTool(defineTool({
		name: "aac_recall",
		label: "AAC recall",
		description: "Retrieve original session evidence. Search literal words (all must match), list recent history without a query, or expand an entry by ID. Defaults to the active branch; scope=session explicitly includes abandoned branches. Results are bounded; follow returned offsets for more.",
		parameters: Type.Object({
			query: Type.Optional(Type.String({ maxLength: 256 })),
			id: Type.Optional(Type.String({ minLength: 1, maxLength: 64 })),
			offset: Type.Optional(Type.Integer({ minimum: 0, maximum: Number.MAX_SAFE_INTEGER,
				description: "Search-result offset, or character offset when expanding an ID." })),
			scope: Type.Optional(StringEnum(["branch", "session"] as const)),
		}),
		async execute(_toolCallId, input, signal, _onUpdate, ctx) {
			if (signal?.aborted) throw new Error("AAC recall cancelled.");
			return {
				content: [{ type: "text", text: recallAacHistory(
					ctx.sessionManager.getEntries(), ctx.sessionManager.getBranch(), input,
				) }], details: {},
			};
		},
	}));

	pi.on("context", (event, ctx) => {
		try {
			const branch = ctx.sessionManager.getBranch();
			const budget = contextBudget(pi, ctx) * (overflowRetry ? 0.5 : 1);
			const view = buildAacView(event.messages, branch, budget, overflowRetry);
			overflowRetry = false;
			if (view.window) pi.appendEntry(AAC_STATE_TYPE, view.window);
			return { messages: view.messages };
		} catch (error) {
			// Pi logs thrown context-hook errors and otherwise sends the unfiltered history.
			// Abort explicitly so a broken checkpoint cannot silently disable the safety boundary.
			overflowRetry = false;
			ctx.abort();
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			return { messages: [] };
		}
	});

	pi.on("session_before_compact", (event, ctx) => {
		if (event.reason === "manual") {
			ctx.ui.notify("AAC manages context automatically; manual compaction is unnecessary.", "info");
			return { cancel: true };
		}
		if (event.reason !== "overflow" || event.signal.aborted) return { cancel: true };
		try {
			const state = readAacWindow(event.branchEntries);
			// A native checkpoint record is required for Pi's single overflow retry.
			// This is existing carryover, not an LLM summarization request.
			return { compaction: {
				summary: state?.checkpoint || "AAC overflow recovery. Retrieve earlier evidence with aac_recall.",
				firstKeptEntryId: event.preparation.firstKeptEntryId,
				tokensBefore: event.preparation.tokensBefore,
				details: { aac: true },
			} };
		} catch (error) {
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			return { cancel: true };
		}
	});
	pi.on("session_compact", (event) => {
		if (event.reason === "overflow" && event.fromExtension &&
			(event.compactionEntry.details as { aac?: boolean } | undefined)?.aac === true) {
			overflowRetry = true;
		}
	});
	pi.on("session_tree", () => { overflowRetry = false; });
}
