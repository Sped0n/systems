import {
    buildSessionProjection,
    estimateTokens,
    type ContextEditEntry,
    type SessionBeforeCompactEvent,
    type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import { BRIEF_MAX_TOKENS } from "./constants.ts";
import { compileTraceEntry, excerpt, renderTrace } from "./view.ts";
import { sanitize } from "./sanitize.ts";

/** Rebuild the older UI view from source, never recursively summarize summaries. */
export function buildBrief(
    event: SessionBeforeCompactEvent,
    contextWindow: number,
): string {
    const { branchEntries, preparation, signal } = event;
    signal.throwIfAborted();
    const tailStart = branchEntries.findIndex(
        (entry) => entry.id === preparation.firstKeptEntryId,
    );
    if (tailStart < 0) throw new Error("Retained-tail boundary is missing.");
    if (!Number.isFinite(contextWindow) || contextWindow <= 0)
        throw new Error("Selected model has no valid context capacity.");

    // Disable checkpoints only in this disposable view. Pi still applies canonical
    // edits across the whole lineage; the original JSONL and native tail are untouched.
    const history: SessionEntry[] = branchEntries.map((entry) =>
        entry.type === "compaction"
            ? {
                  id: entry.id,
                  parentId: entry.parentId,
                  timestamp: entry.timestamp,
                  type: "custom",
                  customType: "ctx-ui-boundary",
                  data: {},
              }
            : entry,
    );
    const edits = new Map<string, ContextEditEntry>();
    for (const entry of branchEntries)
        if (entry.type === "context_edit") edits.set(entry.targetId, entry);
    const older = new Set(
        branchEntries.slice(0, tailStart).map((entry) => entry.id),
    );
    const blocks = buildSessionProjection(history).entries.flatMap(
        ({ sourceEntry, messages }) => {
            signal.throwIfAborted();
            if (!older.has(sourceEntry.id) || !messages.length) return [];
            return compileTraceEntry(sourceEntry, edits.get(sourceEntry.id));
        },
    );
    const budgetTokens = Math.floor(
        Math.min(BRIEF_MAX_TOKENS, contextWindow / 8),
    );
    const focus = event.customInstructions?.trim();
    const introduction = `# Session UI view
Chronological source evidence, not inferred goals or a resolved task state. The original session is intact.
Tool bodies and thinking are folded; source coordinates are entryId:start-end (UTF-16 offsets in recall's full textual view). Read with target=entryId, offset=start; use around for neighboring events.
Continue from the native recent tail, starting at ${preparation.firstKeptEntryId}; it is not duplicated here. Proposals and tool calls are not approval or proof of completion. Historical permission is not renewed.
Omitted user messages may contain applicable constraints. Before consequential action, recall original instructions and surrounding decisions when scope or authorization is unclear; ask if ambiguity remains.
${focus ? `\nUser-supplied compaction focus (not semantically processed):\n${excerpt(sanitize(focus), 600, "\n[…focus excerpt…]\n")}\n` : ""}`;
    const available = budgetTokens * 4 - introduction.length - 2;
    if (available < 600)
        throw new Error(
            "Context capacity is too small for a safe session brief.",
        );
    const summary = `${introduction}\n\n${renderTrace(blocks, available)}`;
    if (
        estimateTokens({
            role: "compactionSummary",
            summary,
            tokensBefore: preparation.tokensBefore,
            timestamp: 0,
        }) > budgetTokens
    )
        throw new Error("Session brief exceeds Pi's estimated token budget.");
    signal.throwIfAborted();
    return summary;
}
