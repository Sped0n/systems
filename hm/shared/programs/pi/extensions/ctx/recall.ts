import { StringEnum } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { recallTraceEntry } from "./view.ts";

type RecallScope = "lineage" | "all";

function recallResult(text: string, details: Record<string, unknown>) {
  return { content: [{ type: "text" as const, text }], details };
}

function readEntry(
  entries: readonly SessionEntry[],
  target: string,
  offset: number,
  scope: RecallScope,
) {
  const raw = entries.find((entry) => entry.id === target);
  const entry = raw && recallTraceEntry(raw);
  if (!entry)
    throw new Error(
      `Entry ${JSON.stringify(target)} has no recallable text in scope '${scope}'. Search first and copy a returned read request.`,
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
      (next ? `\nContinue: recall(${JSON.stringify(next)})` : ""),
    { scope, entryId: entry.id, next },
  );
}

function searchEntries(
  entries: readonly SessionEntry[],
  target: string,
  offset: number,
  scope: RecallScope,
  signal?: AbortSignal,
) {
  const terms = [...new Set(target.toLowerCase().split(/\s+/).filter(Boolean))];
  const frequencies = terms.map(() => 0);
  const hits = entries
    .flatMap((raw, index) => {
      signal?.throwIfAborted();
      const entry = recallTraceEntry(raw);
      if (!entry) return [];
      const text = entry.text.toLowerCase();
      const matches = terms.flatMap((term, termIndex) => {
        const position = text.indexOf(term);
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
          frequencies[match.termIndex] < frequencies[best.termIndex] ||
          (frequencies[match.termIndex] === frequencies[best.termIndex] &&
            match.position < best.position)
            ? match
            : best,
        undefined,
      );
      const start = Math.max(0, (strongest?.position ?? 0) - 120);
      const end = Math.min(start + 600, entry.text.length);
      return {
        id: entry.id,
        timestamp: entry.timestamp,
        role: entry.role,
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
      `offset must be less than ${hits.length} matching entries.`,
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
    offset: 0,
    scope,
  }));
  return recallResult(
    `Scope: ${scope}; matches ${offset + 1}-${end}/${hits.length}.\n\n` +
      selected
        .map(
          (entry, index) =>
            `[${entry.id}; ${entry.timestamp}] ${entry.role}\n${entry.snippet}\nRead: recall(${JSON.stringify(reads[index])})`,
        )
        .join("\n\n") +
      (next ? `\n\nContinue: recall(${JSON.stringify(next)})` : ""),
    { scope, total: hits.length, reads, next },
  );
}

export function registerRecall(pi: ExtensionAPI) {
  pi.registerCommand("recall", {
    description:
      "Recover session context, optionally focused on a question or request",
    handler: async (args) => {
      if (!pi.getActiveTools().includes("recall")) {
        throw new Error("/recall requires the recall tool to be active.");
      }
      const request =
        args.trim() ||
        "Recover the current task's goals, constraints, decisions, progress, blockers, and next steps.";
      pi.sendUserMessage(
        "Recover context from the current Pi session using the recall tool before answering the request below. " +
          "Use summaries as navigation hints, not as substitutes for original messages. " +
          "Browse and search with action:'search', then use action:'read' on matching entry IDs. " +
          "Copy the complete recall arguments returned for reads and continuation. " +
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
    label: "Recall",
    description:
      "Search or read this session's history, including compacted messages. " +
      "Search OR-matches literal keywords, case-insensitively, and returns up to five 600-character snippets ranked by term rarity then recency. " +
      "Read returns up to 12000 characters. Use the returned read/continuation arguments. " +
      "Images are metadata only. No filesystem or cross-session search.",
    promptSnippet: "Search or read session history.",
    promptGuidelines: [
      "Use recall before repeating work or claiming compacted context is unavailable.",
      "Before a consequential action, check active constraints. If an applicable instruction or authorization is unclear, recall the original user message; ask the user if uncertainty remains.",
    ],
    parameters: Type.Object(
      {
        action: StringEnum(["search", "read"] as const),
        target: Type.String({
          maxLength: 500,
          description:
            "Search: literal keywords (empty lists recent entries). Read: exact entry ID.",
        }),
        offset: Type.Integer({
          minimum: 0,
          maximum: Number.MAX_SAFE_INTEGER,
          description:
            "Zero-based: matching entries to skip for search, or UTF-16 characters to skip for read. Start at 0.",
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
      return action === "read"
        ? readEntry(entries, target, offset, scope)
        : searchEntries(entries, target, offset, scope, signal);
    },
  });
}
