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

type RecallScope = "lineage" | "all";

function recallResult(text: string, details: Record<string, unknown>) {
    return { content: [{ type: "text" as const, text }], details };
}

function sourceNavigation(scope: RecallScope) {
    return (
        `Source pointers are entryId:start-end (UTF-16). ` +
        `Read: recall({action:"read",target:entryId,offset:start,scope:"${scope}"}); ` +
        `Around: recall({action:"around",target:entryId,offset:0,scope:"${scope}"}).`
    );
}

function readEntry(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    scope: RecallScope,
) {
    const raw = entries.find((entry) => entry.id === target);
    const entry = raw && recallTraceEntry(raw, entries);
    if (!entry)
        throw new Error(
            `Entry ${JSON.stringify(target)} has no recallable text in scope '${scope}'. Search or list files first, then read a returned source pointer.`,
        );
    if (offset >= entry.text.length)
        throw new Error(`offset must be less than ${entry.text.length}.`);
    const end = Math.min(offset + 12000, entry.text.length);
    const next =
        end < entry.text.length
            ? { action: "read" as const, target, offset: end, scope }
            : null;
    return recallResult(
        `[${entry.id}; ${entry.timestamp}] ${entry.role} (characters ${offset}-${end} of ${entry.text.length})\n` +
            entry.text.slice(offset, end) +
            (next ? `\nContinue: recall(${JSON.stringify(next)})` : "") +
            `\nAround: recall(${JSON.stringify({ action: "around", target, offset: 0, scope })})`,
        {
            scope,
            entryId: entry.id,
            next,
            around: { action: "around", target, offset: 0, scope },
        },
    );
}

function surroundingEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    scope: RecallScope,
    signal?: AbortSignal,
) {
    const trace = entries.flatMap((entry) => {
        signal?.throwIfAborted();
        const text = recallTraceEntry(entry, entries);
        return text ? [text] : [];
    });
    const anchor = trace.findIndex((entry) => entry.id === target);
    if (anchor < 0)
        throw new Error(
            `Entry ${JSON.stringify(target)} has no recallable text in scope '${scope}'.`,
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
        end < total
            ? { action: "around" as const, target, offset: end, scope }
            : null;
    const reads = selected.map((entry) => ({
        action: "read" as const,
        target: entry.id,
        offset: 0,
        scope,
    }));
    return recallResult(
        `Scope: ${scope}; chronological context around ${target}, entries ${offset + 1}-${end}/${total}. ` +
            (scope === "all"
                ? "Append order may interleave branches.\n\n"
                : "Active lineage order.\n\n") +
            sourceNavigation(scope) +
            "\n\n" +
            selected
                .map(
                    (entry) =>
                        `[${entry.timestamp}] [${entry.role}] source ${entry.id}:0-${entry.text.length}\n${entry.text.slice(0, 1200)}${entry.text.length > 1200 ? "…" : ""}`,
                )
                .join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { scope, reads, next },
    );
}

function searchEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    scope: RecallScope,
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
        (term) => new RegExp(term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "iu"),
    );
    const frequencies = terms.map(() => 0);
    const hits = compileTrace(entries)
        .flatMap((entry, index) => {
            signal?.throwIfAborted();
            // Search typed source blocks, never flatten intention and observation together.
            if (!entry.searchable) return [];
            const matches = patterns.flatMap((pattern, termIndex) => {
                const position = entry.text.search(pattern);
                if (position < 0) return [];
                frequencies[termIndex]++;
                return [{ termIndex, position }];
            });
            if (terms.length && !matches.length) return [];
            return [{ ...entry, matches, index }];
        })
        .map((entry) => {
            // Count each term once per entry. A rare diagnostic should outweigh
            // several common words, even when those words appear many times.
            const score = entry.matches.reduce(
                (sum, match) => sum + 1 / frequencies[match.termIndex],
                0,
            );
            const strongest = entry.matches.reduce<
                (typeof entry.matches)[number] | undefined
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
            const start = Math.max(0, (strongest?.position ?? 0) - 120);
            const end = Math.min(start + 600, entry.text.length);
            return {
                id: entry.entryId,
                timestamp: entry.timestamp,
                role: entry.role,
                offset: entry.offset + start,
                end: entry.offset + end,
                snippet: `${start ? "…" : ""}${entry.text.slice(start, end)}${end < entry.text.length ? "…" : ""}`,
                score,
                index: entry.index,
            };
        })
        .sort((a, b) => b.score - a.score || b.index - a.index);
    if (!hits.length)
        return recallResult(`No matching history in scope '${scope}'.`, {
            scope,
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
            ? { action: "search" as const, target, offset: end, scope }
            : null;
    const reads = selected.map((entry) => ({
        action: "read" as const,
        target: entry.id,
        offset: entry.offset,
        scope,
    }));
    return recallResult(
        `Scope: ${scope}; matching blocks ${offset + 1}-${end}/${hits.length}.\n` +
            sourceNavigation(scope) +
            "\n\n" +
            selected
                .map(
                    (entry) =>
                        `[${entry.timestamp}] [${entry.role}] source ${entry.id}:${entry.offset}-${entry.end}\n${entry.snippet}`,
                )
                .join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { scope, total: hits.length, reads, next },
    );
}

function fileEntries(
    entries: readonly SessionEntry[],
    target: string,
    offset: number,
    scope: RecallScope,
    signal?: AbortSignal,
) {
    const entriesById = new Map(entries.map((entry) => [entry.id, entry]));
    const trace = compileTrace(entries);
    const callCounts = new Map<string, number>();
    const results = new Map<string, TraceBlock[]>();
    const callKey = (block: TraceBlock) =>
        JSON.stringify([block.toolName, block.callId]);
    for (const block of trace) {
        signal?.throwIfAborted();
        if (entriesById.get(block.entryId)?.type === "context_edit") continue;
        const key = callKey(block);
        if (block.role === "tool_call")
            callCounts.set(key, (callCounts.get(key) ?? 0) + 1);
        if (block.role === "tool_result" && block.callId) {
            const matches = results.get(key);
            if (matches) matches.push(block);
            else results.set(key, [block]);
        }
    }
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
            `No recorded file operations in scope '${scope}'.`,
            {
                scope,
                total: 0,
                next: null,
            },
        );
    if (offset >= operations.length)
        throw new Error(
            `offset must be less than ${operations.length} file operations.`,
        );
    const selected = operations.slice(offset, offset + 5);
    const end = offset + selected.length;
    const next =
        end < operations.length
            ? { action: "files" as const, target, offset: end, scope }
            : null;
    const reads: {
        action: "read";
        target: string;
        offset: number;
        scope: RecallScope;
    }[] = [];
    const pointer = (block: TraceBlock) => {
        reads.push({
            action: "read",
            target: block.entryId,
            offset: block.offset,
            scope,
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
        const key = callKey(call);
        // A shared call ID across branches is not proof that a result belongs to
        // this call. Pair only unambiguous, same-tool descendant evidence.
        const matches = (results.get(key) ?? []).filter((result) => {
            let parent = entriesById.get(result.entryId)?.parentId;
            for (let count = 0; parent && count < entries.length; count++) {
                if (parent === call.entryId) return true;
                parent = entriesById.get(parent)?.parentId;
            }
            return false;
        });
        const result =
            matches.length === 1 && callCounts.get(key) === 1
                ? matches[0]
                : undefined;
        const outcome = result
            ? `${result.isError ? "error" : "result"} ${pointer(result)}`
            : matches.length
              ? "ambiguous result pairing; inspect around"
              : "no recorded result";
        return `${path}\n  ${file.operation} call ${source} → ${outcome}`;
    });
    return recallResult(
        `Scope: ${scope}; file operations ${offset + 1}-${end}/${operations.length}. ` +
            "Recorded paths, ordered by path then chronology; calls are attempts, not current file state.\n" +
            sourceNavigation(scope) +
            "\n\n" +
            rows.join("\n\n") +
            (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
        { scope, total: operations.length, reads, next },
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
                    "Stay on the active lineage unless the user asks about other branches; do not search other session files. " +
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
            "Search or read this session's history, including compacted messages. " +
            "Call recall directly, not through codemode or other tools. " +
            "Files lists five recorded native read/write/edit operations with call/result pointers; target is a literal path substring (empty lists all). Calls are attempts, not current file state. " +
            "Search OR-matches literal keywords, case-insensitively, and returns up to five role-tagged 600-character source-block snippets ranked by term rarity then recency. " +
            "Read returns up to 12000 UTF-16 characters of the full textual view, including write/edit payloads. UI and search coordinates refer to this view. Search excludes recall echoes and generated compaction summaries. " +
            "Around returns five chronological excerpts starting two recallable entries before an entry ID; continue to follow later events. " +
            "Use source pointers with the shared navigation instructions and copy continuation arguments. " +
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
                scope: StringEnum(["lineage", "all"] as const, {
                    description:
                        "lineage: active branch. all: every branch in this session.",
                }),
            },
            { additionalProperties: false },
        ),
        async execute(_id, params, signal, _onUpdate, ctx) {
            signal?.throwIfAborted();
            const { action, target, offset, scope } = params;
            const entries =
                scope === "all"
                    ? ctx.sessionManager.getEntries()
                    : ctx.sessionManager.getBranch();
            if (action === "files")
                return fileEntries(entries, target, offset, scope, signal);
            if (action === "read")
                return readEntry(entries, target, offset, scope);
            if (action === "around")
                return surroundingEntries(
                    entries,
                    target,
                    offset,
                    scope,
                    signal,
                );
            return searchEntries(entries, target, offset, scope, signal);
        },
    });
}
