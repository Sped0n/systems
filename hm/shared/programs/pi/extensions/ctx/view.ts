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
                add("user", text, { uiText: text });
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
                        const path =
                            typeof args?.path === "string"
                                ? args.path
                                : args?.file_path;
                        const file: TraceBlock["file"] =
                            (part.name === "read" ||
                                part.name === "write" ||
                                part.name === "edit") &&
                            typeof path === "string" &&
                            path.length > 0
                                ? { path, operation: part.name }
                                : undefined;
                        const subject = [
                            "path",
                            "file_path",
                            "command",
                            "query",
                            "target",
                        ].flatMap((key) =>
                            typeof args?.[key] === "string"
                                ? [`${key}=${JSON.stringify(args[key])}`]
                                : [],
                        )[0];
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
                                    : excerpt(
                                          `${part.name}${subject ? ` ${subject}` : ""}`,
                                          200,
                                          "…",
                                      ),
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
    entries: readonly SessionEntry[],
): TraceBlock[] {
    if (entry.type === "context_edit") {
        const target = entries.find((source) => source.id === entry.targetId);
        if (target) return compileTraceEntry(target, entry);
    }
    return compileTraceEntry(entry);
}

export function compileTrace(entries: readonly SessionEntry[]): TraceBlock[] {
    return entries.flatMap((entry) => sourceBlocks(entry, entries));
}

/** Sanitized full textual view. Raw JSONL remains authoritative for binary data. */
export function recallTraceEntry(
    entry: SessionEntry,
    entries: readonly SessionEntry[] = [],
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

/** Bounded chronological UI. Reserve user space before selecting newest work. */
export function renderTrace(
    blocks: readonly TraceBlock[],
    budgetChars: number,
): string {
    const ui = uiTrace(blocks);
    if (!ui.length)
        return "(no earlier dialogue)".slice(0, Math.max(0, budgetChars));
    const render = (block: TraceBlock, text: string) =>
        `[entry ${block.entryId}; ${block.role}; source ${tracePointer(block)}]\n${text}`;
    const complete = ui.map((block) => render(block, block.uiText!));
    if (
        complete.reduce((length, row) => length + row.length + 2, -2) <=
        budgetChars
    )
        return complete.join("\n\n");

    const gap = (first: number, last: number) =>
        `[…${last - first + 1} UI blocks omitted: ${ui[first].entryId} through ${ui[last].entryId}; recall around/read…]`;
    // Reserve a gap per retained row so interleaved omissions can never exceed the cap.
    const gapReserve =
        90 +
        2 *
            ui.reduce(
                (maximum, block) => Math.max(maximum, block.entryId.length),
                0,
            );
    const available = Math.max(0, budgetChars - gapReserve);
    const users = ui.flatMap((block, index) =>
        block.role === "user" ? [index] : [],
    );
    const userBudget = Math.floor(available * 0.8);
    const userLimit = Math.max(
        480,
        Math.floor(userBudget / Math.max(1, users.length)) - gapReserve,
    );
    const selected = new Map<number, string>();
    let used = 0;
    const select = (index: number, limit: number, ceiling: number) => {
        const block = ui[index];
        const row = render(
            block,
            excerpt(block.uiText!, limit, "\n[…excerpt; read source…]\n"),
        );
        const cost = row.length + 2 + gapReserve;
        if (used + cost > ceiling) return;
        selected.set(index, row);
        used += cost;
    };
    // Oldest intent and newest corrections survive even when user evidence alone overflows.
    if (users.length) select(users[0], userLimit, userBudget);
    for (const index of users.slice(1).reverse())
        select(index, userLimit, userBudget);
    for (let index = ui.length - 1; index >= 0; index--)
        if (ui[index].role !== "user") select(index, 800, available);

    const output: string[] = [];
    let missing = -1;
    for (let index = 0; index < ui.length; index++) {
        const row = selected.get(index);
        if (!row) {
            if (missing < 0) missing = index;
            continue;
        }
        if (missing >= 0) {
            output.push(gap(missing, index - 1));
            missing = -1;
        }
        output.push(row);
    }
    if (missing >= 0) output.push(gap(missing, ui.length - 1));
    return output.join("\n\n");
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
                    text: `[Older ${message.toolName} output omitted from active context. Read original: recall(${JSON.stringify({ action: "read", target: source.id, offset: 0, scope: "lineage" })})]`,
                },
            ],
        };
    });
}
