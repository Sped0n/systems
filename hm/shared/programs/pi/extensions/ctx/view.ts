import type { NestedToolCallRecord } from "@earendil-works/pi-ai";
import {
    estimateTokens,
    sessionEntryToContextMessages,
    type ContextEditEntry,
    type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import {
    LARGE_TOOL_RESULT_CHARS,
    PROTECTED_ASSISTANT_TURNS,
    PROTECTED_RECENT_TOKENS,
} from "./constants.ts";
import { sanitize } from "./sanitize.ts";

type ContextMessage = ReturnType<typeof sessionEntryToContextMessages>[number];

/** Coordinates are entry-local UTF-16 offsets in the full view, never UI offsets. */
export interface TraceBlock {
    entryId: string;
    timestamp: string;
    role:
        | "user"
        | "assistant"
        | "thinking"
        | "tool_call"
        | "tool_result"
        | "nested_call"
        | "other";
    text: string;
    header: string;
    offset: number;
    end: number;
    uiText?: string;
    searchable: boolean;
    callId?: string;
    toolName?: string;
    isError?: boolean;
    nestedStatus?: NestedToolCallRecord["status"];
    contextReplacement?: boolean;
    file?: { path: string; operation: "read" | "write" | "edit" };
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function contentText(content: string | readonly unknown[]): string {
    if (typeof content === "string") return sanitize(content);
    return content
        .flatMap((part) => {
            if (!isRecord(part)) return [];
            if (part.type === "text" && typeof part.text === "string")
                return [sanitize(part.text)];
            if (part.type === "image" && typeof part.mimeType === "string")
                return [`[image: ${part.mimeType}]`];
            return [];
        })
        .join("\n");
}

function isRecallTool(name: string): boolean {
    return name === "recall";
}

function fileOperation(
    name: string,
    args: Record<string, unknown> | undefined,
): TraceBlock["file"] {
    const path = typeof args?.path === "string" ? args.path : args?.file_path;
    return (name === "read" || name === "write" || name === "edit") &&
        typeof path === "string" &&
        path.length > 0
        ? { path, operation: name }
        : undefined;
}

/** Collapse complete skill expansions in UI text, not quoted code or raw recall. */
function collapseSkills(text: string): string {
    const lines = text.split("\n");
    const output: string[] = [];
    let fence: string | undefined;
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        const delimiter = line.match(/^[ \t]*(`{3,}|~{3,})(.*)$/);
        if (delimiter) {
            if (!fence) fence = delimiter[1];
            else if (
                delimiter[1][0] === fence[0] &&
                delimiter[1].length >= fence.length &&
                !delimiter[2].trim()
            )
                fence = undefined;
        }
        const skill =
            !fence && line.match(/^<skill\s+name="([^"\r\n]+)"[^>\r\n]*>\r?$/);
        const end = skill
            ? lines.findIndex(
                  (candidate, position) =>
                      position > index &&
                      /^<\/skill>[ \t]*\r?$/.test(candidate),
              )
            : -1;
        if (skill && end >= 0) {
            output.push(
                `[skill: ${skill[1]}]${lines[end].endsWith("\r") ? "\r" : ""}`,
            );
            index = end;
        } else output.push(line);
    }
    return output.join("\n");
}

function toolPreview(
    name: string,
    args: Record<string, unknown> | undefined,
): string {
    const key = ["path", "file_path", "command", "query", "target"].find(
        (key) => typeof args?.[key] === "string",
    );
    return excerpt(
        `${name}${key ? ` ${key}=${JSON.stringify(args![key])}` : ""}`,
        200,
        "…",
    );
}

/** Compile original content once; projections never rewrite its coordinates. */
export function compileTraceEntry(
    entry: SessionEntry,
    edit?: ContextEditEntry,
): TraceBlock[] {
    const source = edit ?? entry;
    const blocks: TraceBlock[] = [];
    let cursor = 0;
    const add = (
        role: TraceBlock["role"],
        text: string,
        options: Partial<
            Pick<
                TraceBlock,
                | "uiText"
                | "searchable"
                | "callId"
                | "toolName"
                | "isError"
                | "nestedStatus"
                | "file"
            >
        > = {},
    ) => {
        text = sanitize(text);
        if (!text) return;
        const header = `[${role}${edit ? `; context replacement of ${entry.id}` : ""}]\n`;
        const offset = cursor + header.length;
        blocks.push({
            entryId: source.id,
            timestamp: source.timestamp,
            role,
            text,
            header,
            offset,
            end: offset + text.length,
            searchable: true,
            contextReplacement: !!edit,
            ...options,
            uiText:
                options.uiText === undefined
                    ? undefined
                    : `${edit ? `[context replacement of ${entry.id}]\n` : ""}${options.uiText}`,
        });
        cursor = offset + text.length + 2;
    };
    if (entry.type === "context_edit") {
        add(
            "other",
            `Context edit of ${entry.targetId}\n${JSON.stringify(entry.replacement)}`,
        );
        return blocks;
    }
    if (edit?.replacement === null) {
        add("other", `Context omission of ${entry.id}`);
        return blocks;
    }
    for (const original of sessionEntryToContextMessages(entry)) {
        // Use the same content-only replacement semantics as Pi's projection.
        let message = original;
        if (
            edit?.replacement &&
            ["user", "assistant", "toolResult", "custom"].includes(
                original.role,
            )
        ) {
            const replacement = edit.replacement.content;
            const content =
                (original.role === "assistant" ||
                    original.role === "toolResult") &&
                typeof replacement === "string"
                    ? [{ type: "text" as const, text: replacement }]
                    : replacement;
            message = { ...original, content } as ContextMessage;
        }
        switch (message.role) {
            case "user": {
                const text = contentText(message.content);
                add("user", text, { uiText: collapseSkills(text) });
                break;
            }
            case "assistant":
                for (const part of message.content) {
                    if (part.type === "text")
                        add("assistant", part.text, { uiText: part.text });
                    if (part.type === "thinking")
                        add("thinking", part.thinking);
                    if (part.type === "toolCall") {
                        const args = part.arguments;
                        const file = fileOperation(part.name, args);
                        add(
                            "tool_call",
                            `${part.name} (call ${part.id})\n${JSON.stringify(args)}`,
                            {
                                callId: part.id,
                                toolName: part.name,
                                file,
                                searchable: !isRecallTool(part.name),
                                uiText: isRecallTool(part.name)
                                    ? undefined
                                    : toolPreview(part.name, args),
                            },
                        );
                    }
                }
                break;
            case "toolResult":
                add(
                    "tool_result",
                    `${message.toolName} ${message.isError ? "error" : "result"} (call ${message.toolCallId})\n${contentText(message.content)}`,
                    {
                        callId: message.toolCallId,
                        toolName: message.toolName,
                        isError: message.isError,
                        searchable: !isRecallTool(message.toolName),
                    },
                );
                // Append metadata after the original result so existing UTF-16 pointers
                // keep their meaning. A canonical replacement must not expose hidden args.
                if (!edit && message.nestedCalls) {
                    for (const call of message.nestedCalls.calls) {
                        const file = fileOperation(call.name, call.arguments);
                        add(
                            "nested_call",
                            `${call.name} (nested call ${call.id}; parent ${message.toolCallId})\n${JSON.stringify(call)}\nResult body not recorded in nested metadata.`,
                            {
                                toolName: call.name,
                                file,
                                nestedStatus: call.status,
                                searchable: !isRecallTool(call.name),
                                uiText: isRecallTool(call.name)
                                    ? undefined
                                    : `${toolPreview(call.name, call.arguments)} (nested ${call.status}; result body not recorded${call.arguments === undefined ? "; arguments omitted" : ""})`,
                            },
                        );
                    }
                    if (!message.nestedCalls.complete)
                        add(
                            "other",
                            "Nested call record incomplete: calls or arguments may be omitted, or calls unfinished.",
                            {
                                uiText: "Nested call record incomplete; recall this result for recorded metadata.",
                            },
                        );
                }
                break;
            case "bashExecution":
                add("tool_result", `$ ${message.command}\n${message.output}`, {
                    uiText: message.excludeFromContext
                        ? undefined
                        : excerpt(
                              `$ ${JSON.stringify(message.command)} (exit ${message.exitCode ?? "unknown"})`,
                              200,
                              "…",
                          ),
                });
                break;
            case "branchSummary":
                add(
                    "other",
                    `[branch handoff; fallible summary]\n${message.summary}`,
                    {
                        uiText: `[branch handoff; fallible summary]\n${message.summary}`,
                    },
                );
                break;
            case "compactionSummary":
                add(
                    "other",
                    `[compaction; navigation hint]\n${message.summary}`,
                    {
                        searchable: false,
                    },
                );
                break;
            case "custom":
                add(
                    "other",
                    `${message.customType}\n${contentText(message.content)}`,
                    {
                        searchable: false,
                    },
                );
                break;
            case "system":
                add("other", JSON.stringify(message), { searchable: false });
                break;
        }
    }
    return blocks;
}

function sourceBlocks(
    entry: SessionEntry,
    entries: readonly SessionEntry[] | ReadonlyMap<string, SessionEntry>,
): TraceBlock[] {
    if (entry.type === "context_edit") {
        const target =
            "get" in entries
                ? entries.get(entry.targetId)
                : entries.find((source) => source.id === entry.targetId);
        if (target) return compileTraceEntry(target, entry);
    }
    return compileTraceEntry(entry);
}

export function compileTrace(
    entries: readonly SessionEntry[],
    entriesById: ReadonlyMap<string, SessionEntry> = new Map(
        entries.map((entry) => [entry.id, entry]),
    ),
): TraceBlock[] {
    return entries.flatMap((entry) => sourceBlocks(entry, entriesById));
}

/** Sanitized full textual view. Raw JSONL remains authoritative for binary data. */
export function recallTraceEntry(
    entry: SessionEntry,
    entries: readonly SessionEntry[] | ReadonlyMap<string, SessionEntry> = [],
) {
    const blocks = sourceBlocks(entry, entries);
    if (!blocks.length) return undefined;
    const text = blocks.map((block) => block.header + block.text).join("\n\n");
    return {
        id: entry.id,
        timestamp: entry.timestamp,
        role: [...new Set(blocks.map((block) => block.role))].join("+"),
        text,
        blocks,
    };
}

/** Clip with a visible middle omission; never join fragments as an intact quote. */
export function excerpt(text: string, limit: number, marker: string): string {
    if (text.length <= limit) return text;
    if (limit < marker.length) return marker.slice(0, Math.max(0, limit));
    const visible = limit - marker.length;
    const head = Math.ceil(visible / 2);
    const tail = Math.floor(visible / 2);
    return text.slice(0, head) + marker + (tail ? text.slice(-tail) : "");
}

export function tracePointer(block: TraceBlock): string {
    return `${block.entryId}:${block.offset}-${block.end}`;
}

/** UI projection: dialogue and folded calls, never tool bodies or inferred task state. */
export function uiTrace(blocks: readonly TraceBlock[]): TraceBlock[] {
    const results = new Map<string, TraceBlock[]>();
    for (const block of blocks) {
        if (block.role === "tool_result" && block.callId)
            results.set(block.callId, [
                ...(results.get(block.callId) ?? []),
                block,
            ]);
    }
    return blocks.flatMap((block) => {
        if (block.uiText === undefined) return [];
        const matches = block.callId ? results.get(block.callId) : undefined;
        const result = matches?.length === 1 ? matches[0] : undefined;
        const suffix =
            block.role === "tool_call" && result
                ? ` → ${result.isError ? "error" : "result"} ${tracePointer(result)}`
                : "";
        return [{ ...block, uiText: sanitize(block.uiText) + suffix }];
    });
}

function fileActivity(ui: readonly TraceBlock[], budgetChars: number): string {
    const files = new Map<
        string,
        { latest: TraceBlock; counts: Record<string, number> }
    >();
    for (const block of ui) {
        if (!block.file || block.contextReplacement) continue;
        const { path, operation } = block.file;
        const group = files.get(path) ?? { latest: block, counts: {} };
        group.latest = block;
        group.counts[operation] = (group.counts[operation] ?? 0) + 1;
        files.delete(path);
        files.set(path, group);
    }
    if (!files.size) return "";
    const heading =
        "## File activity\nRecorded operations, not current file state. Latest paths first.";
    const rows: string[] = [];
    const omitted = () =>
        rows.length < files.size
            ? `\n[…${files.size - rows.length} file paths omitted; recall files…]`
            : "";
    for (const { latest, counts } of [...files.values()].reverse()) {
        const countText = Object.entries(counts)
            .map(([name, count]) => name + "×" + count)
            .join(", ");
        const row = `- ${countText}; latest ${tracePointer(latest)}\n  ${latest.uiText}`;
        rows.push(row);
        if (
            [heading, ...rows].join("\n").length + omitted().length >
            budgetChars
        ) {
            rows.pop();
            break;
        }
    }
    return rows.length ? [heading, ...rows].join("\n") + omitted() : "";
}

/** Bounded chronological UI; exact gap costs leave room for more source evidence. */
export function renderTrace(
    blocks: readonly TraceBlock[],
    budgetChars: number,
): string {
    const ui = uiTrace(blocks);
    if (!ui.length)
        return "(no earlier dialogue)".slice(0, Math.max(0, budgetChars));
    const render = (index: number, text: string) => {
        const block = ui[index];
        return `[entry ${block.entryId}; ${block.role}; source ${tracePointer(block)}]\n${text}`;
    };
    const complete = ui.map((block, index) => render(index, block.uiText!));
    if (
        complete.reduce((length, row) => length + row.length + 2, -2) <=
        budgetChars
    )
        return complete.join("\n\n");

    const gap = (first: number, last: number) =>
        `[…${last - first + 1} UI blocks omitted: ${ui[first].entryId} through ${ui[last].entryId}; recall around/read…]`;
    const gapCost = (first: number, last: number) =>
        first <= last ? gap(first, last).length + 2 : 0;
    const users = ui.flatMap((block, index) =>
        block.role === "user" ? [index] : [],
    );
    // Older user evidence comes first; native recent context already carries current work.
    const userOverhead = users.reduce(
        (sum, index) => sum + render(index, "").length + 2,
        0,
    );
    const userLimit = Math.max(
        480,
        Math.floor((budgetChars - userOverhead) / Math.max(1, users.length)),
    );
    const selected: { index: number; row: string }[] = [];
    let used = gapCost(0, ui.length - 1) - 2;
    const select = (index: number, limit: number, ceiling: number) => {
        const row = render(
            index,
            excerpt(ui[index].uiText!, limit, "\n[…excerpt; read source…]\n"),
        );
        let position = selected.findIndex((item) => item.index >= index);
        if (position < 0) position = selected.length;
        const previous =
            selected[position]?.index === index
                ? selected[position]
                : undefined;
        if (previous) {
            if (used + row.length - previous.row.length > ceiling) return;
            used += row.length - previous.row.length;
            previous.row = row;
        } else {
            const first = (selected[position - 1]?.index ?? -1) + 1;
            const last = (selected[position]?.index ?? ui.length) - 1;
            const delta =
                row.length +
                2 +
                gapCost(first, index - 1) +
                gapCost(index + 1, last) -
                gapCost(first, last);
            if (used + delta > ceiling) return;
            used += delta;
            selected.splice(position, 0, { index, row });
        }
    };
    // Keep the opening request, then intact corrections before excerpts of larger messages.
    if (users.length) select(users[0], userLimit, budgetChars);
    const recentUsers = users.slice(1).reverse();
    for (const index of recentUsers)
        if (ui[index].uiText!.length <= userLimit)
            select(index, userLimit, budgetChars);
    for (const index of recentUsers)
        if (ui[index].uiText!.length > userLimit)
            select(index, userLimit, budgetChars);
    const clippedUsers = users
        .filter(
            (index) =>
                selected.some((item) => item.index === index) &&
                ui[index].uiText!.length > userLimit,
        )
        .sort((a, b) => ui[a].uiText!.length - ui[b].uiText!.length || a - b);
    for (const index of clippedUsers)
        select(
            index,
            Math.min(
                ui[index].uiText!.length,
                userLimit + Math.max(0, budgetChars - used),
            ),
            budgetChars,
        );

    // Walk backward to pair each short reply with its nearest assistant, not an earlier turn.
    let reply: (typeof selected)[number] | undefined;
    for (let index = ui.length - 1; index >= 0; index--) {
        const block = ui[index];
        if (block.role === "user") {
            reply =
                block.uiText!.length <= 80
                    ? selected.find((item) => item.index === index)
                    : undefined;
        } else if (block.role === "assistant" && reply) {
            const context = `; reply-context ${tracePointer(block)}`;
            if (used + context.length <= budgetChars) {
                reply.row = reply.row.replace("]\n", `${context}]\n`);
                used += context.length;
            }
            reply = undefined;
        }
    }
    const files = fileActivity(
        ui,
        Math.min(1800, Math.max(0, budgetChars - used - 2)),
    );
    const dialogueBudget = budgetChars - (files ? files.length + 2 : 0);
    for (let index = ui.length - 1; index >= 0; index--)
        if (
            ui[index].role !== "user" &&
            (!ui[index].file || ui[index].contextReplacement || !files)
        )
            select(index, 800, dialogueBudget);

    const output: string[] = [];
    let next = 0;
    for (const { index, row } of selected) {
        if (next < index) output.push(gap(next, index - 1));
        output.push(row);
        next = index + 1;
    }
    if (next < ui.length) output.push(gap(next, ui.length - 1));
    // Very small callers still get a bounded omission marker, never an over-budget row.
    const dialogue = output.join("\n\n").slice(0, Math.max(0, dialogueBudget));
    return files ? `${dialogue}\n\n${files}` : dialogue;
}

function toolResultKey(message: ContextMessage): string | undefined {
    return message.role === "toolResult"
        ? JSON.stringify([
              message.timestamp,
              message.toolCallId,
              message.toolName,
          ])
        : undefined;
}

/** Mask only old, exact source results, without mutating persisted or edited context. */
export function maskConsumedToolResults(
    messages: readonly ContextMessage[],
    contextEntries: readonly SessionEntry[],
): ContextMessage[] {
    let protectedStart = messages.length;
    let tokens = 0;
    let assistants = 0;
    while (
        protectedStart > 0 &&
        (tokens < PROTECTED_RECENT_TOKENS ||
            assistants < PROTECTED_ASSISTANT_TURNS)
    ) {
        const message = messages[--protectedStart];
        tokens += estimateTokens(message);
        if (message.role === "assistant") assistants++;
    }
    const sources = new Map<string, SessionEntry[]>();
    for (const entry of contextEntries) {
        if (entry.type !== "message") continue;
        const key = toolResultKey(entry.message);
        if (key) sources.set(key, [...(sources.get(key) ?? []), entry]);
    }
    return messages.map((message, index) => {
        if (
            index >= protectedStart ||
            message.role !== "toolResult" ||
            isRecallTool(message.toolName)
        )
            return message;
        const matches = sources.get(toolResultKey(message)!);
        if (matches?.length !== 1) return message;
        const source = matches[0];
        if (
            source.type !== "message" ||
            source.message.role !== "toolResult" ||
            JSON.stringify(source.message.content) !==
                JSON.stringify(message.content)
        )
            return message;
        if (contentText(message.content).length <= LARGE_TOOL_RESULT_CHARS)
            return message;
        return {
            ...message,
            content: [
                {
                    type: "text" as const,
                    text: `[Older ${message.toolName} output omitted from active context. Read original: recall(${JSON.stringify({ action: "read", target: source.id, offset: 0 })})]`,
                },
            ],
        };
    });
}
