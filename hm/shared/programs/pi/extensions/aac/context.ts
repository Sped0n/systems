import { createHash } from "node:crypto";

import {
	sessionEntryToContextMessages,
	type ContextEvent,
	type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import { isAacRecallEntry } from "./recall.ts";

export const AAC_STATE_TYPE = "aac-window";
export const AAC_CHECKPOINT_CHARACTERS_MAX = 6_000;
type Message = ContextEvent["messages"][number];
export type AacWindow = {
	version: 1;
	afterId: string | null;
	checkpoint: string;
	sourceIds: string[];
	stale: boolean;
};
type IndexedMessage = { message: Message; index: number; id?: string };

export function readAacWindow(branch: SessionEntry[]): AacWindow | undefined {
	const entry = branch.findLast((item) => item.type === "custom" && item.customType === AAC_STATE_TYPE);
	if (!entry || entry.type !== "custom") return undefined;
	const state = entry.data as Partial<AacWindow> | undefined;
	if (!state || state.version !== 1 || typeof state.checkpoint !== "string" ||
		state.checkpoint.length > AAC_CHECKPOINT_CHARACTERS_MAX || typeof state.stale !== "boolean" ||
		!Array.isArray(state.sourceIds) || state.sourceIds.length > 16 ||
		!state.sourceIds.every((id) => typeof id === "string") ||
		(state.afterId !== null && typeof state.afterId !== "string")) {
		throw new Error("AAC checkpoint is invalid; navigate before it with /tree or disable AAC.");
	}
	const ancestors = branch.slice(0, branch.indexOf(entry));
	if (state.afterId !== null && !ancestors.some((item) => item.id === state.afterId)) {
		throw new Error("AAC window boundary is missing from this branch; navigate before the checkpoint.");
	}
	if (state.sourceIds.some((id) => !ancestors.some((item) => item.id === id && isAacRecallEntry(item)))) {
		throw new Error("AAC checkpoint references missing original evidence; navigate before the checkpoint.");
	}
	return state as AacWindow;
}

/** Conservative UTF-8 estimate; image data is charged separately, not as base64 text. */
export function aacMessageTokens(message: Message): number {
	const text = JSON.stringify(message, (_key, value) =>
		value && typeof value === "object" && value.type === "image" && typeof value.data === "string"
			? { ...value, data: "" } : value);
	const images = "content" in message && Array.isArray(message.content)
		? message.content.filter((part) => part.type === "image").length : 0;
	return Math.ceil(Buffer.byteLength(text, "utf8") / 2) + images * 4_096;
}

function messageKey(message: Message): string {
	const identity = message.role === "toolResult" ? message.toolCallId :
		createHash("sha256").update(JSON.stringify("content" in message ? message.content : message)).digest("hex");
	return `${message.role}:${message.timestamp}:${identity}`;
}

function indexMessages(messages: Message[], branch: SessionEntry[]): IndexedMessage[] {
	const entries = new Map<string, { index: number; id: string }[]>();
	branch.forEach((entry, index) => {
		for (const message of sessionEntryToContextMessages(entry)) {
			const key = messageKey(message);
			const matches = entries.get(key) ?? [];
			matches.push({ index, id: entry.id });
			entries.set(key, matches);
		}
	});
	return messages.slice().reverse().map((message) => ({
		message, index: branch.length, ...entries.get(messageKey(message))?.pop(),
	})).reverse();
}

/** Treat parallel calls and all their results as one indivisible exchange. */
function messageGroups(messages: IndexedMessage[]): IndexedMessage[][] {
	const groups: IndexedMessage[][] = [];
	for (let index = 0; index < messages.length; index++) {
		const item = messages[index];
		const message = item.message;
		if (message.role === "toolResult") continue;
		if (message.role !== "assistant") {
			groups.push([item]);
			continue;
		}
		if (message.stopReason === "error" || message.stopReason === "aborted") continue;
		const calls = message.content.filter((part) => part.type === "toolCall");
		const group = [item];
		while (messages[index + 1]?.message.role === "toolResult") group.push(messages[++index]);
		const results = group.slice(1).map((part) => part.message);
		if (calls.length === results.length && calls.every((call) =>
			results.some((result) => result.role === "toolResult" && result.toolCallId === call.id))) {
			groups.push(group);
		}
	}
	return groups;
}

function contextNote(text: string): Message {
	return { role: "custom", customType: "aac-context", content: text, display: false, timestamp: 0 };
}

function windowNote(state: AacWindow, branch: SessionEntry[]): Message {
	const first = branch.find((entry) => entry.type === "message")?.id ?? "none";
	return contextNote([
		"AAC working window. Original session history is available through aac_recall.",
		`History begins at ${first}; previous window ends at ${state.afterId ?? "start"}.`,
		state.stale ? "Checkpoint may be stale: automatic fallback omitted newer history. Recall evidence as needed." : "Agent-authored checkpoint (verify claims against original evidence when needed):",
		state.checkpoint || "No checkpoint was saved. Recover missing task context with aac_recall.",
		state.sourceIds.length ? `Sources: ${state.sourceIds.join(", ")}` : "",
	].filter(Boolean).join("\n"));
}

function omitToolResult(item: IndexedMessage): IndexedMessage {
	return item.message.role === "toolResult" ? {
		...item, message: { ...item.message, content: [{ type: "text",
			text: `AAC omitted a large tool result. Retrieve original entry ${item.id ?? "via recent aac_recall"}.` }] },
	} : item;
}

function recentTail(tail: IndexedMessage[], budget: number): IndexedMessage[] {
	const kept: IndexedMessage[] = [];
	let used = 0;
	for (const original of messageGroups(tail).reverse()) {
		let group = original;
		let cost = group.reduce((sum, item) => sum + aacMessageTokens(item.message), 0);
		if (used + cost > budget && kept.length === 0) {
			group = group.map(omitToolResult);
			cost = group.reduce((sum, item) => sum + aacMessageTokens(item.message), 0);
		}
		if (used + cost > budget) break;
		kept.unshift(...group);
		used += cost;
	}
	return kept;
}

/** Build a view only; originals and provider-specific tool-call signatures remain untouched. */
export function buildAacView(
	messages: Message[], branch: SessionEntry[], budget: number, forceRollover = false,
): { messages: Message[]; window?: AacWindow; tokens: number } {
	if (!Number.isFinite(budget) || budget <= 0) throw new Error("AAC requires a finite positive context budget.");
	const reminder = contextNote("AAC context is nearing its limit. Call aac_checkpoint alone now with a concise goal, decisions, constraints, unfinished work, and source IDs. Then continue the task; this is internal bookkeeping.");
	const reminderTokens = aacMessageTokens(reminder);
	budget -= reminderTokens;
	const state = readAacWindow(branch);
	const boundary = state?.afterId ? branch.findIndex((entry) => entry.id === state.afterId) : -1;
	const indexed = indexMessages(messages, branch);
	let tail = indexed.filter((item) => item.index > boundary &&
		!(state && item.message.role === "compactionSummary"));
	// Pi may have hidden this request behind an older native compaction checkpoint.
	const userEntry = branch.findLast((entry) => entry.type === "message" && entry.message.role === "user");
	const latestUser = userEntry?.type === "message"
		? indexed.find((item) => item.id === userEntry.id) ?? {
			message: userEntry.message, index: branch.indexOf(userEntry), id: userEntry.id,
		} : undefined;
	const assemble = (items: IndexedMessage[], window = state): Message[] => [
		...(window ? [windowNote(window, branch)] : []),
		...(window && latestUser && !items.some((item) => item.id === latestUser.id) ? [latestUser.message] : []),
		...items.map((item) => item.message),
	];
	tail = messageGroups(tail).flat().map((item) =>
		item.message.role === "toolResult" && aacMessageTokens(item.message) > budget * 0.2
			? omitToolResult(item) : item);
	let view = assemble(tail);
	let tokens = view.reduce((sum, message) => sum + aacMessageTokens(message), 0);
	let window: AacWindow | undefined;
	if (forceRollover || tokens > budget) {
		window = { version: 1, afterId: state?.afterId ?? null, checkpoint: state?.checkpoint ?? "", sourceIds: state?.sourceIds ?? [], stale: true };
		const fixed = assemble([], window).reduce((sum, message) => sum + aacMessageTokens(message), 0);
		if (fixed + 512 > budget) {
			throw new Error("AAC cannot fit the latest request and checkpoint. Shorten the request or select a larger-context model.");
		}
		const target = Math.max(fixed + 512, Math.floor(budget * 0.4));
		const kept = recentTail(tail, target - fixed);
		const firstIndex = kept.find((item) => item.id)?.index ?? branch.length;
		window.afterId = branch[firstIndex - 1]?.id ?? null;
		view = assemble(kept, window);
		tokens = view.reduce((sum, message) => sum + aacMessageTokens(message), 0);
	}
	if (tokens > budget) throw new Error("AAC context exceeds its safety budget; select a larger-context model.");
	if (tokens > budget * 0.7) {
		view.push(reminder);
		tokens += reminderTokens;
	}
	return { messages: view, window, tokens };
}
