import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import {
    buildSessionProjection,
    estimateTokens,
    migrateSessionEntries,
    parseSessionEntries,
    type SessionBeforeCompactEvent,
    type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import { buildBrief } from "./brief.ts";
import {
    compileTraceEntry,
    recallTraceEntry,
    renderTrace,
    type TraceBlock,
} from "./view.ts";

// Structural replay only: no provider calls, session writes, or transcript output.
const args = process.argv.slice(2);
if (args[0] !== "--baseline" || !args[1] || args.length < 3)
    throw new Error(
        "Usage: node --import tsx extensions/ctx/replay.ts --baseline /path/to/previous/ctx session.jsonl ...",
    );
const baseline = (await import(
    pathToFileURL(resolve(args[1], "brief.ts")).href
)) as { buildBrief: typeof buildBrief };
const capacities = [32_000, 272_000];
const totals = capacities.map((capacity) => ({
    capacity,
    olderUserRequests: 0,
    before: metrics(),
    after: metrics(),
    matched: metrics(),
    matchedRegressions: 0,
}));
const unboundedUiTokens: number[] = [];
function metrics() {
    return {
        characters: 0,
        estimatedTokens: 0,
        visibleUsers: 0,
        completeUserRequests: 0,
        assistantExcerpts: 0,
        filePaths: 0,
        replyContexts: 0,
        milliseconds: [] as number[],
    };
}
let checkpoints = 0;
let skipped = 0;
let checkedPointers = 0;
for (const path of args.slice(2)) {
    const records = parseSessionEntries(await readFile(path, "utf8"));
    migrateSessionEntries(records);
    const entries = records.filter(
        (entry): entry is SessionEntry => entry.type !== "session",
    );
    const byId = new Map(entries.map((entry) => [entry.id, entry]));
    const full = new Map<string, ReturnType<typeof recallTraceEntry>>();
    const getFull = (id: string) => {
        if (!full.has(id)) {
            const entry = byId.get(id);
            assert.ok(entry, `Unknown source: ${id}`);
            full.set(id, recallTraceEntry(entry, byId));
        }
        return full.get(id)!;
    };
    for (const checkpoint of entries) {
        if (checkpoint.type !== "compaction") continue;
        const branch: SessionEntry[] = [];
        const visited = new Set<string>();
        for (
            let entry = byId.get(checkpoint.parentId ?? "");
            entry;
            entry = byId.get(entry.parentId ?? "")
        ) {
            assert.ok(!visited.has(entry.id), "Cyclic session lineage");
            visited.add(entry.id);
            branch.push(entry);
        }
        branch.reverse();
        const boundary = branch.findIndex(
            (entry) => entry.id === checkpoint.firstKeptEntryId,
        );
        if (boundary < 0) {
            skipped++;
            continue;
        }
        checkpoints++;
        const olderIds = new Set(
            branch.slice(0, boundary).map((entry) => entry.id),
        );
        const edits = new Map(
            branch
                .filter((entry) => entry.type === "context_edit")
                .map((entry) => [entry.targetId, entry]),
        );
        const history = branch.map((entry): SessionEntry =>
            entry.type === "compaction"
                ? {
                      id: entry.id,
                      parentId: entry.parentId,
                      timestamp: entry.timestamp,
                      type: "custom",
                      customType: "replay-boundary",
                      data: {},
                  }
                : entry,
        );
        const blocks = buildSessionProjection(history).entries.flatMap(
            ({ sourceEntry, messages }) =>
                olderIds.has(sourceEntry.id) && messages.length
                    ? compileTraceEntry(sourceEntry, edits.get(sourceEntry.id))
                    : [],
        );
        unboundedUiTokens.push(
            estimateTokens({
                role: "compactionSummary",
                summary: renderTrace(blocks, Number.MAX_SAFE_INTEGER),
                tokensBefore: checkpoint.tokensBefore,
                timestamp: 0,
            }),
        );
        const users = blocks.filter((block) => block.role === "user");
        // Count exact wording outside skill wrappers, not the injected instruction bodies.
        const wording = (block: TraceBlock) =>
            block.text
                .split(
                    /^<skill\s+name="[^"\r\n]+"[^>\r\n]*>\r?\n[\s\S]*?^<\/skill>[ \t]*\r?$/gm,
                )
                .map((part) => part.trim())
                .filter(Boolean);
        const event: SessionBeforeCompactEvent = {
            type: "session_before_compact",
            reason: "manual",
            willRetry: false,
            branchEntries: branch,
            signal: new AbortController().signal,
            preparation: {
                firstKeptEntryId: checkpoint.firstKeptEntryId!,
                tokensBefore: checkpoint.tokensBefore,
                messagesToSummarize: [],
                turnPrefixMessages: [],
                isSplitTurn: false,
                fileOps: {
                    read: new Set(),
                    written: new Set(),
                    edited: new Set(),
                },
                settings: {
                    enabled: true,
                    reserveTokens: 16384,
                    keepRecentTokens: 20000,
                },
            },
        };
        for (const total of totals) {
            total.olderUserRequests += users.filter(
                (block) => wording(block).length,
            ).length;
            let baselineTokens = 0;
            const complete = { before: 0, after: 0, matched: 0 };
            for (const [label, compiler] of [
                ["before", baseline.buildBrief],
                ["after", buildBrief],
                ["matched", buildBrief],
            ] as const) {
                const capacity =
                    label === "matched"
                        ? Math.min(total.capacity, baselineTokens * 8)
                        : total.capacity;
                const start = performance.now();
                const summary = compiler(event, capacity);
                const measured = total[label];
                measured.milliseconds.push(performance.now() - start);
                if (label !== "before")
                    assert.equal(
                        compiler(event, capacity),
                        summary,
                        "Nondeterministic brief",
                    );
                const tokens = estimateTokens({
                    role: "compactionSummary",
                    summary,
                    tokensBefore: checkpoint.tokensBefore,
                    timestamp: 0,
                });
                if (label === "before") baselineTokens = tokens;
                assert.ok(
                    tokens <= Math.floor(Math.min(8192, capacity / 8)),
                    "Brief exceeds budget",
                );
                measured.characters += summary.length;
                measured.estimatedTokens += tokens;
                const visible = new Map<string, string>();
                const sources: string[] = [];
                const rows = [
                    ...summary.matchAll(
                        /^\[entry ([^;]+); ([^;]+); source ([^\n]+)\]\n/gm,
                    ),
                ];
                for (const row of rows) {
                    const text = summary
                        .slice(row.index! + row[0].length)
                        .split(
                            /\n\n(?:\[entry |\[…\d+ UI blocks|## File activity)/,
                            1,
                        )[0];
                    visible.set(row[1], text);
                    sources.push(row[3].split(";", 1)[0]);
                    const reply = row[3].match(/; reply-context (\S+)/);
                    if (reply) {
                        measured.replyContexts++;
                        sources.push(reply[1]);
                    }
                    if (row[2] === "assistant") measured.assistantExcerpts++;
                }
                for (const match of summary.matchAll(
                    /^- [^\n]+; latest (\S+)\n/gm,
                ))
                    sources.push(match[1]);
                const filePaths = new Set<string>();
                for (const source of sources) {
                    const match = source.match(/^([^:]+):(\d+)-(\d+)$/);
                    assert.ok(match, `Invalid pointer: ${source}`);
                    const view = getFull(match[1]);
                    assert.ok(view, "Empty source view");
                    const block = view.blocks.find(
                        (block) =>
                            block.offset === Number(match[2]) &&
                            block.end === Number(match[3]),
                    );
                    assert.ok(
                        block,
                        `Pointer does not identify a full source block: ${source}`,
                    );
                    assert.equal(
                        view.text.slice(block.offset, block.end),
                        block.text,
                    );
                    if (block.file) filePaths.add(block.file.path);
                    checkedPointers++;
                }
                measured.filePaths += filePaths.size;
                for (const user of users) {
                    const text = visible.get(user.entryId);
                    if (text === undefined) continue;
                    measured.visibleUsers++;
                    const parts = wording(user);
                    if (
                        parts.length &&
                        parts.every((part) => text.includes(part))
                    ) {
                        measured.completeUserRequests++;
                        complete[label]++;
                    }
                }
            }
            if (complete.matched < complete.before) total.matchedRegressions++;
        }
    }
}
for (const total of totals) {
    assert.equal(
        total.matchedRegressions,
        0,
        `Matched-budget user retention regressed at ${total.capacity} tokens`,
    );
    for (const label of ["before", "after", "matched"] as const)
        total[label].milliseconds.sort((a, b) => a - b);
}
unboundedUiTokens.sort((a, b) => a - b);
console.log(
    JSON.stringify(
        {
            sessions: args.length - 2,
            checkpoints,
            skipped,
            checkedPointers,
            unboundedUi: {
                excludesPreambleAndRecentTail: true,
                medianEstimatedTokens:
                    unboundedUiTokens[
                        Math.floor(unboundedUiTokens.length / 2)
                    ] ?? 0,
                p95EstimatedTokens:
                    unboundedUiTokens[
                        Math.floor(unboundedUiTokens.length * 0.95)
                    ] ?? 0,
                maxEstimatedTokens: unboundedUiTokens.at(-1) ?? 0,
                fit4000: unboundedUiTokens.filter((tokens) => tokens <= 4000)
                    .length,
                fit8192: unboundedUiTokens.filter((tokens) => tokens <= 8192)
                    .length,
                fit32000: unboundedUiTokens.filter((tokens) => tokens <= 32000)
                    .length,
                fit272000: unboundedUiTokens.filter(
                    (tokens) => tokens <= 272000,
                ).length,
            },
            totals: totals.map((total) => ({
                ...total,
                ...Object.fromEntries(
                    (["before", "after", "matched"] as const).map((label) => {
                        const { milliseconds, ...counts } = total[label];
                        return [
                            label,
                            {
                                ...counts,
                                meanCharacters: milliseconds.length
                                    ? Math.round(
                                          counts.characters /
                                              milliseconds.length,
                                      )
                                    : 0,
                                p95Milliseconds:
                                    milliseconds[
                                        Math.min(
                                            milliseconds.length - 1,
                                            Math.floor(
                                                milliseconds.length * 0.95,
                                            ),
                                        )
                                    ] ?? null,
                            },
                        ];
                    }),
                ),
            })),
        },
        null,
        2,
    ),
);
