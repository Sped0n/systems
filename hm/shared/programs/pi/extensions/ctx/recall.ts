import { StringEnum } from "@earendil-works/pi-ai";
import type {
    ExtensionAPI,
    SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import {
    compileTrace,
    excerpt,
    recallTraceEntry,
    tracePointer,
    type TraceBlock,
} from "./view.ts";

function recallResult(text: string, details: Record<string, unknown>) {
    return { content: [{ type: "text" as const, text }], details };
}

function sourceNavigation() {
    return (
        "Source pointers are entryId:start-end (UTF-16). " +
        'Read: recall({action:"read",target:entryId,offset:start}); ' +
        'Around: recall({action:"around",target:entryId,offset:0}).'
    );
}

function readEntry(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
) {
    const raw = entries.find((entry) => entry.id === target);
    const entry = raw && recallTraceEntry(raw, entries);
    if (!entry)
        throw new Error(
            `Entry ${JSON.stringify(target)} has no recallable text in the active lineage. Search or list files first, then read a returned source pointer.`,
        );
    if (offset >= entry.text.length)
        throw new Error(`offset must be less than ${entry.text.length}.`);
    const end = Math.min(offset + 12000, entry.text.length);
    const next =
        end < entry.text.length
            ? { action: "read" as const, target, offset: end }
            : null;
    return recallResult(
        `[${entry.id}; ${entry.timestamp}] ${entry.role} (characters ${offset}-${end} of ${entry.text.length})\n` +
            entry.text.slice(offset, end) +
            (next ? `\nContinue: recall(${JSON.stringify(next)})` : "") +
            `\nAround: recall(${JSON.stringify({ action: "around", target, offset: 0 })})`,
        {
            entryId: entry.id,
            next,
            around: { action: "around", target, offset: 0 },
        },
    );
}

function surroundingEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    signal?: AbortSignal,
) {
    const entriesById = new Map(entries.map((entry) => [entry.id, entry]));
    const trace = entries.flatMap((entry) => {
        signal?.throwIfAborted();
        const text = recallTraceEntry(entry, entriesById);
        return text ? [text] : [];
    });
    const anchor = trace.findIndex((entry) => entry.id === target);
    if (anchor < 0)
        throw new Error(
            `Entry ${JSON.stringify(target)} has no recallable text in the active lineage.`,
        );
    const start = Math.max(0, anchor - 2);
    const total = trace.length - start;
    if (offset >= total)
        throw new Error(
            `offset must be less than ${total} surrounding entries.`,
        );
    const selected = trace.slice(start + offset, start + offset + 5);
    const end = offset + selected.length;
    const next =
        end < total ? { action: "around" as const, target, offset: end } : null;
    const reads = selected.map((entry) => ({
        action: "read" as const,
        target: entry.id,
        offset: 0,
    }));
    return recallResult(
        `Active lineage; chronological context around ${target}, entries ${offset + 1}-${end}/${total}.\n\n` +
            sourceNavigation() +
            "\n\n" +
            selected
                .map(
                    (entry) =>
                        `[${entry.timestamp}] [${entry.role}] source ${entry.id}:0-${entry.text.length}\n${entry.text.slice(0, 1200)}${entry.text.length > 1200 ? "…" : ""}`,
                )
                .join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { reads, next },
    );
}

/** null marks ambiguous recorded evidence; undefined means no associated result. */
function recordedToolPairs(
    entriesById: ReadonlyMap<string, SessionEntry>,
    trace: readonly TraceBlock[],
    selected: readonly TraceBlock[],
    signal?: AbortSignal,
): Map<TraceBlock, TraceBlock | null> {
    const calls = new Map<string, TraceBlock[]>();
    const results = new Map<string, TraceBlock[]>();
    const callKey = (block: TraceBlock) =>
        JSON.stringify([block.toolName, block.callId]);
    // Off-page duplicates must still make a selected key ambiguous.
    const selectedKeys = new Set(
        selected.filter((block) => block.callId).map(callKey),
    );
    if (!selectedKeys.size) return new Map();
    for (const block of trace) {
        signal?.throwIfAborted();
        if (!block.callId || entriesById.get(block.entryId)?.type !== "message")
            continue;
        const collection =
            block.role === "tool_call"
                ? calls
                : block.role === "tool_result"
                  ? results
                  : undefined;
        if (!collection) continue;
        const key = callKey(block);
        if (!selectedKeys.has(key)) continue;
        const matches = collection.get(key);
        if (matches) matches.push(block);
        else collection.set(key, [block]);
    }
    const pairs = new Map<TraceBlock, TraceBlock | null>();
    for (const [key, candidates] of calls) {
        for (const call of candidates) {
            signal?.throwIfAborted();
            // A matching tool and call ID alone do not establish provenance.
            const matches = (results.get(key) ?? []).filter((result) => {
                let parent = entriesById.get(result.entryId)?.parentId;
                for (
                    let count = 0;
                    parent && count < entriesById.size;
                    count++
                ) {
                    signal?.throwIfAborted();
                    if (parent === call.entryId) return true;
                    parent = entriesById.get(parent)?.parentId;
                }
                return false;
            });
            if (matches.length === 1 && candidates.length === 1) {
                pairs.set(call, matches[0]);
                pairs.set(matches[0], call);
            } else if (matches.length) {
                pairs.set(call, null);
                for (const result of matches) pairs.set(result, null);
            }
        }
    }
    return pairs;
}

function sourceExcerpt(
    block: TraceBlock,
    position: number | undefined,
    limit: number,
) {
    // Unmatched output uses its literal tail; unmatched calls use their head.
    const start =
        position === undefined
            ? block.role === "tool_result"
                ? Math.max(0, block.text.length - (limit - 2))
                : 0
            : Math.max(0, position - Math.min(120, Math.floor(limit / 3)));
    // Reserve room for visible clipping markers without rewriting source offsets.
    const end = Math.min(start + limit - 2, block.text.length);
    return {
        offset: block.offset + start,
        end: block.offset + end,
        text: `${start ? "…" : ""}${block.text.slice(start, end)}${end < block.text.length ? "…" : ""}`,
    };
}

function searchEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    signal?: AbortSignal,
) {
    const terms = [
        ...new Map(
            target
                .split(/\s+/)
                .filter(Boolean)
                .map((term) => [term.toLowerCase(), term]),
        ).values(),
    ];
    // Search original text: lowercasing can expand Unicode and invalidate offsets.
    const patterns = terms.map(
        (term) =>
            new RegExp(term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "giu"),
    );
    const frequencies = terms.map(() => 0);
    const entriesById = new Map(entries.map((entry) => [entry.id, entry]));
    const trace = compileTrace(entries, entriesById);
    const words = /\S+/g;
    let documentCount = 0;
    let totalLength = 0;
    const matchedBlocks = trace.flatMap((block, index) => {
        signal?.throwIfAborted();
        if (!block.searchable) return [];
        documentCount++;
        words.lastIndex = 0;
        let length = 0;
        while (words.test(block.text)) length++;
        totalLength += length;
        const matches = patterns.flatMap((pattern, termIndex) => {
            pattern.lastIndex = 0;
            const first = pattern.exec(block.text);
            if (!first) return [];
            // Keep exact frequencies without allocating an array per occurrence.
            let count = 1;
            while (pattern.test(block.text)) count++;
            frequencies[termIndex]++;
            return [{ termIndex, position: first.index, count }];
        });
        if (terms.length && !matches.length) return [];
        return [{ block, matches, index, length }];
    });
    const averageLength = totalLength / Math.max(1, documentCount);
    const hits = matchedBlocks
        .map((hit) => {
            // Saturate repeated literal matches and normalize block length so
            // boilerplate cannot swamp concise evidence with the same terms.
            const normalization =
                1.2 * (0.25 + (0.75 * hit.length) / averageLength);
            const score = hit.matches.reduce((sum, match) => {
                const frequency = frequencies[match.termIndex];
                const rarity = Math.log1p(
                    (documentCount - frequency + 0.5) / (frequency + 0.5),
                );
                return (
                    sum +
                    (rarity * match.count * 2.2) / (match.count + normalization)
                );
            }, 0);
            const strongest = hit.matches.reduce<
                (typeof hit.matches)[number] | undefined
            >(
                (best, match) =>
                    !best ||
                    frequencies[match.termIndex] <
                        frequencies[best.termIndex] ||
                    (frequencies[match.termIndex] ===
                        frequencies[best.termIndex] &&
                        match.position < best.position)
                        ? match
                        : best,
                undefined,
            );
            return { ...hit, score, position: strongest?.position ?? 0 };
        })
        .sort((a, b) => b.score - a.score || b.index - a.index);
    if (!hits.length)
        return recallResult("No matching history in the active lineage.", {
            total: 0,
            next: null,
        });
    if (offset >= hits.length)
        throw new Error(
            `offset must be less than ${hits.length} matching blocks.`,
        );
    const selected = hits.slice(offset, offset + 5);
    const end = offset + selected.length;
    const next =
        end < hits.length
            ? { action: "search" as const, target, offset: end }
            : null;
    const pairs = recordedToolPairs(
        entriesById,
        trace,
        selected.map((hit) => hit.block),
        signal,
    );
    const reads: {
        action: "read";
        target: string;
        offset: number;
    }[] = [];
    const render = (
        block: TraceBlock,
        position: number | undefined,
        limit: number,
        kind: string,
    ) => {
        const snippet = sourceExcerpt(block, position, limit);
        reads.push({
            action: "read",
            target: block.entryId,
            offset: snippet.offset,
        });
        const replacement =
            entriesById.get(block.entryId)?.type === "context_edit"
                ? "; context replacement, not recorded evidence"
                : "";
        const error = block.isError ? "; tool reported error" : "";
        return `[${block.timestamp}] [${block.role}] ${kind}${replacement}${error} source ${block.entryId}:${snippet.offset}-${snippet.end}\n${snippet.text}`;
    };
    const selectedBlocks = new Set(selected.map((hit) => hit.block));
    const turns = new Map<TraceBlock, TraceBlock>();
    let turn: TraceBlock | undefined;
    for (const block of trace) {
        signal?.throwIfAborted();
        if (entriesById.get(block.entryId)?.type !== "message") continue;
        if (block.role === "user") turn = block;
        else if (turn && selectedBlocks.has(block)) turns.set(block, turn);
    }
    const renderedTurns = new Set(
        selected
            .filter((hit) => hit.block.role === "user")
            .map((hit) => hit.block.entryId),
    );
    const rows = selected.map((hit) => {
        signal?.throwIfAborted();
        const partner = pairs.get(hit.block);
        const user = turns.get(hit.block);
        const turn =
            user && !renderedTurns.has(user.entryId) ? user : undefined;
        if (turn) renderedTurns.add(turn.entryId);
        const matched = excerpt(
            JSON.stringify(hit.matches.map((match) => terms[match.termIndex])),
            160,
            "…",
        );
        const row = render(
            hit.block,
            hit.position,
            (partner ? 420 : 600) - (turn ? 120 : 0),
            "match",
        );
        const related = partner
            ? "\n" +
              render(
                  partner,
                  hits.find((candidate) => candidate.block === partner)
                      ?.position,
                  180,
                  "related recorded evidence",
              )
            : partner === null
              ? "\nRecorded counterpart is ambiguous; inspect around."
              : "";
        const context = turn
            ? render(
                  turn,
                  0,
                  120,
                  "recorded turn start (historical, not approval)",
              ) + "\n"
            : "";
        return context + row + "\nMatched terms: " + matched + related;
    });
    return recallResult(
        `Active lineage; matching blocks ${offset + 1}-${end}/${hits.length}.\n` +
            `Expand if needed: recall(${JSON.stringify(reads[0])})` +
            "\nRelated blocks are recorded evidence, not completion verdicts. Changing query restarts offset at 0.\n\n" +
            rows.join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { total: hits.length, reads, next },
    );
}

function fileEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    signal?: AbortSignal,
) {
    const entriesById = new Map(entries.map((entry) => [entry.id, entry]));
    const trace = compileTrace(entries, entriesById);
    const query = target.toLowerCase();
    const operations = trace
        .filter((block) => block.file?.path.toLowerCase().includes(query))
        .sort((a, b) =>
            a.file!.path < b.file!.path
                ? -1
                : a.file!.path > b.file!.path
                  ? 1
                  : 0,
        );
    if (!operations.length)
        return recallResult(
            "No recorded file operations in the active lineage.",
            {
                total: 0,
                next: null,
            },
        );
    if (offset >= operations.length)
        throw new Error(
            `offset must be less than ${operations.length} file operations.`,
        );
    const selected = operations.slice(offset, offset + 5);
    const pairs = recordedToolPairs(entriesById, trace, selected, signal);
    const end = offset + selected.length;
    const next =
        end < operations.length
            ? { action: "files" as const, target, offset: end }
            : null;
    const reads: {
        action: "read";
        target: string;
        offset: number;
    }[] = [];
    const pointer = (block: TraceBlock) => {
        reads.push({
            action: "read",
            target: block.entryId,
            offset: block.offset,
        });
        return tracePointer(block);
    };
    const rows = selected.map((call) => {
        signal?.throwIfAborted();
        const file = call.file!;
        const source = pointer(call);
        const path = excerpt(
            JSON.stringify(file.path),
            240,
            "[…path excerpt…]",
        );
        if (entriesById.get(call.entryId)?.type === "context_edit")
            return `${path}\n  ${file.operation} context replacement ${source} (not a recorded call)`;
        const result = pairs.get(call);
        const outcome = result
            ? `${result.isError ? "error" : "result"} ${pointer(result)}`
            : result === null
              ? "ambiguous result pairing; inspect around"
              : "no recorded result";
        return `${path}\n  ${file.operation} call ${source} → ${outcome}`;
    });
    return recallResult(
        `Active lineage; file operations ${offset + 1}-${end}/${operations.length}. ` +
            "Recorded paths, ordered by path then chronology; calls are attempts, not current file state.\n" +
            sourceNavigation() +
            "\n\n" +
            rows.join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { total: operations.length, reads, next },
    );
}

export function registerRecall(pi: ExtensionAPI) {
    pi.registerCommand("recall", {
        description:
            "Recover session context, optionally focused on a question or request",
        handler: async (args) => {
            if (!pi.getActiveTools().includes("recall")) {
                throw new Error(
                    "/recall requires the recall tool to be active.",
                );
            }
            const request =
                args.trim() ||
                "Recover the current task's goals, constraints, decisions, progress, blockers, and next steps.";
            pi.sendUserMessage(
                "Recover context from the current Pi session using the recall tool before answering the request below. " +
                    "Use summaries as navigation hints, not as substitutes for original messages. " +
                    "Browse and search with action:'search', use action:'files' for recorded file operations, " +
                    "action:'around' for chronological neighbors, then action:'read' for complete evidence. " +
                    "Follow consequential decisions through proposal, user acceptance or correction, action, and validation; do not infer approval or completion from a proposal. " +
                    "Use source pointers with the shared navigation instructions and copy continuation arguments. " +
                    "Recall only the active lineage; do not search other branches or session files. " +
                    "Trace the user's intent and changes of direction. If the answer depends on current file contents, " +
                    "read the relevant files afresh and distinguish historical decisions from current state. " +
                    "Do not rerun commands or repeat edits merely to reconstruct history. " +
                    "Give a concise evidence-backed answer with entry IDs for key details, and state any gaps.\n\n" +
                    `Recall request:\n${request}`,
                { deliverAs: "followUp" },
            );
        },
    });

    pi.registerTool({
        name: "recall",
        exposure: "model-only",
        label: "Recall",
        description:
            "Search or read this session's active lineage, including compacted messages. " +
            "Call recall directly, not through codemode or other tools. " +
            "Files lists five recorded native read/write/edit operations with call/result pointers; target is a literal path substring (empty lists all). Calls are attempts, not current file state. " +
            "Search OR-matches literal keywords, case-insensitively, and returns up to five matching blocks ranked by literal-term relevance then recency. Hits include separately labelled recorded call/result evidence when pairing is unambiguous, sharing a 600-character excerpt budget per hit. " +
            "Read returns up to 12000 UTF-16 characters of the full textual view, including write/edit payloads. Pointers entryId:start-end use UTF-16 offsets in this view. Search excludes recall echoes and generated compaction summaries; hits may include historical user-turn anchors within the same excerpt budget, not renewed approval. " +
            "Start around with target=entryId, offset=0; five chronological excerpts begin two recallable entries before the anchor. " +
            "Read pointers with target=entryId, offset=start. Copy continuation arguments; changing query restarts offset at zero. " +
            "Images are metadata only. No filesystem or cross-session search.",
        promptSnippet:
            "Retrieve original session evidence and surrounding decisions.",
        promptGuidelines: [
            "Use recall before repeating work or claiming compacted context is unavailable.",
            "Before a consequential action, check active constraints. If an applicable instruction or authorization is unclear, recall the original user message; ask the user if uncertainty remains.",
        ],
        parameters: Type.Object(
            {
                action: StringEnum([
                    "search",
                    "read",
                    "around",
                    "files",
                ] as const),
                target: Type.String({
                    maxLength: 500,
                    description:
                        "Search: literal keywords (empty lists recent entries). Files: case-insensitive literal path substring (empty lists all). Read/around: exact entry ID.",
                }),
                offset: Type.Integer({
                    minimum: 0,
                    maximum: Number.MAX_SAFE_INTEGER,
                    description:
                        "Zero-based: matching blocks for search, operations for files, UTF-16 characters for read, or entries from the initial neighborhood for around. Start at 0.",
                }),
            },
            { additionalProperties: false },
        ),
        async execute(_id, params, signal, _onUpdate, ctx) {
            signal?.throwIfAborted();
            const { action, target, offset } = params;
            const entries = ctx.sessionManager.getBranch();
            if (action === "files")
                return fileEntries(entries, target, offset, signal);
            if (action === "read") return readEntry(entries, target, offset);
            if (action === "around")
                return surroundingEntries(entries, target, offset, signal);
            return searchEntries(entries, target, offset, signal);
        },
    });
}
