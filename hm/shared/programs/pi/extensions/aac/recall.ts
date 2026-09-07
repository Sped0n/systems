import { sessionEntryToContextMessages, type SessionEntry } from "@earendil-works/pi-coding-agent";

export type AacRecallInput = {
	query?: string;
	id?: string;
	offset?: number;
	scope?: "branch" | "session";
};

/** Original messages, including extension reports, rather than state or summary records. */
export function isAacRecallEntry(entry: SessionEntry): boolean {
	return entry.type === "message" || entry.type === "custom_message";
}

function entryText(entry: SessionEntry): string {
	return sessionEntryToContextMessages(entry).map((message) => {
		if ("summary" in message) return message.summary;
		if (message.role === "bashExecution") return `$ ${message.command}\n${message.output}`;
		if (!("content" in message)) return "";
		if (typeof message.content === "string") return message.content;
		return message.content.map((part) => {
			if (part.type === "text") return part.text;
			if (part.type === "thinking") return part.thinking;
			if (part.type === "toolCall") return `${part.name} ${JSON.stringify(part.arguments)}`;
			return "[image: binary content remains in the original session]";
		}).join("\n");
	}).join("\n");
}

/** Same-session evidence only; explicit entry expansion obeys the same lineage boundary as search. */
export function recallAacHistory(
	entries: SessionEntry[], branch: SessionEntry[], input: AacRecallInput,
): string {
	const active = new Set(branch.map((entry) => entry.id));
	const candidates = (input.scope === "session" ? entries : branch).filter(isAacRecallEntry);
	const offset = input.offset ?? 0;
	const describe = (entry: SessionEntry) => {
		const role = entry.type === "message" ? entry.message.role : entry.type;
		return `id=${entry.id} parent=${entry.parentId ?? "root"} ${active.has(entry.id) ? "active-branch" : "other-branch"} ${role} ${entry.timestamp}`;
	};
	if (input.id) {
		const entry = candidates.find((item) => item.id === input.id);
		if (!entry) return "AAC entry not found in the selected scope. Use scope=session only to recover other-branch evidence.";
		const text = entryText(entry);
		const end = Math.min(offset + 6_000, text.length);
		return `${describe(entry)}\n${text.slice(offset, end)}\n` +
			(end < text.length ? `Continue with id=${entry.id} offset=${end}.` : "[end of entry]");
	}
	const terms = (input.query ?? "").toLowerCase().split(/\s+/u).filter(Boolean);
	const matches: string[] = [];
	let skipped = 0;
	for (let index = candidates.length - 1; index >= 0; index--) {
		const entry = candidates[index];
		const text = entryText(entry);
		if (!text) continue;
		const lower = text.toLowerCase();
		if (!terms.every((term) => lower.includes(term))) continue;
		if (skipped++ < offset) continue;
		if (matches.length === 5) return `${matches.join("\n\n")}\n\nMore matches: offset=${offset + 5}.`;
		const hit = terms.length ? lower.indexOf(terms[0]) : 0;
		const start = Math.max(0, hit - 120);
		matches.push(`${describe(entry)}\n${start ? "…" : ""}${text.slice(start, start + 800)}${text.length > start + 800 ? "…" : ""}`);
	}
	return matches.length ? `${matches.join("\n\n")}\n\nExpand with id and optional character offset.` : "AAC found no matching history in the selected scope.";
}
