import {
  sessionEntryToContextMessages,
  type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import {
  LARGE_TOOL_RESULT_CHARS,
  OBSERVER_TOOL_RESULT_CHARS,
} from "./constants.ts";
import { sanitize } from "./sanitize.ts";

export type TraceRole =
  | "user"
  | "assistant"
  | "tool_call"
  | "tool_result"
  | "other";

export interface TraceBlock {
  entryId: string;
  timestamp: string;
  role: TraceRole;
  text: string;
}

type ContextMessage = ReturnType<typeof sessionEntryToContextMessages>[number];

function contentText(
  content: string | readonly unknown[],
  includeThinking = false,
): string {
  if (typeof content === "string") return sanitize(content);
  return content
    .flatMap((part) => {
      if (!isRecord(part)) return [];
      if (part.type === "text" && typeof part.text === "string")
        return [part.text];
      if (
        includeThinking &&
        part.type === "thinking" &&
        typeof part.thinking === "string"
      )
        return [part.thinking];
      if (part.type === "image" && typeof part.mimeType === "string")
        return [`[image: ${part.mimeType}]`];
      return [];
    })
    .map(sanitize)
    .filter((text) => text.trim().length > 0)
    .join("\n");
}

function conciseArguments(name: string, value: unknown): unknown {
  if ((name !== "write" && name !== "edit") || !isRecord(value)) return value;
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => {
      if (key === "content" || key === "patch" || key === "newText")
        return [key, "[payload omitted]"];
      if (name === "edit" && key === "edits" && Array.isArray(item))
        return [key, `[${item.length} edit payload(s) omitted]`];
      return [key, item];
    }),
  );
}

function isRecallTool(name: string): boolean {
  return name === "recall" || name === "vcc_recall";
}

type TraceCoordinates = Pick<TraceBlock, "entryId" | "timestamp">;
type Message = Extract<SessionEntry, { type: "message" }>["message"];

function compileToolResult(
  coordinates: TraceCoordinates,
  message: Extract<Message, { role: "toolResult" }>,
): TraceBlock[] {
  if (isRecallTool(message.toolName)) return [];
  const text = contentText(message.content, true);
  return text
    ? [
        {
          ...coordinates,
          role: "tool_result",
          text: `${message.toolName}${message.isError ? " error" : " result"}\n${text}`,
        },
      ]
    : [];
}

function compileAssistant(
  coordinates: TraceCoordinates,
  message: Extract<Message, { role: "assistant" }>,
): TraceBlock[] {
  const blocks: TraceBlock[] = [];
  const text = contentText(message.content);
  if (text) blocks.push({ ...coordinates, role: "assistant", text });
  for (const part of message.content) {
    if (part.type !== "toolCall" || isRecallTool(part.name)) continue;
    blocks.push({
      ...coordinates,
      role: "tool_call",
      text: `${part.name}(${JSON.stringify(conciseArguments(part.name, part.arguments))})`,
    });
  }
  return blocks;
}

function compileMessageEntry(
  entry: Extract<SessionEntry, { type: "message" }>,
): TraceBlock[] {
  const coordinates = { entryId: entry.id, timestamp: entry.timestamp };
  const message = entry.message;
  if (message.role === "bashExecution") {
    return message.excludeFromContext
      ? []
      : [
          {
            ...coordinates,
            role: "tool_result",
            text: sanitize(`$ ${message.command}\n${message.output}`),
          },
        ];
  }
  if (message.role === "compactionSummary" || message.role === "branchSummary")
    return [
      {
        ...coordinates,
        role: "other",
        text: sanitize(message.summary),
      },
    ];
  if (message.role === "toolResult")
    return compileToolResult(coordinates, message);
  if (message.role === "user") {
    const text = contentText(message.content);
    return text ? [{ ...coordinates, role: "user", text }] : [];
  }
  return message.role === "assistant"
    ? compileAssistant(coordinates, message)
    : [];
}

/** Lower one native entry into the shared, role-aware trace representation. */
export function compileTraceEntry(entry: SessionEntry): TraceBlock[] {
  if (entry.type === "branch_summary") {
    return entry.summary
      ? [
          {
            entryId: entry.id,
            timestamp: entry.timestamp,
            role: "other",
            text: sanitize(entry.summary),
          },
        ]
      : [];
  }
  return entry.type === "message" ? compileMessageEntry(entry) : [];
}

export function compileTrace(entries: readonly SessionEntry[]): TraceBlock[] {
  return entries.flatMap(compileTraceEntry);
}

function renderBlock(block: TraceBlock): string {
  return `[entry ${block.entryId}; ${block.role}; ${block.timestamp}]\n${block.text}`;
}

/** Reserve space for conversation before allocating tool-result excerpts. */
export function renderObserverTrace(
  entries: readonly SessionEntry[],
  tokenBudget: number,
): string {
  const blocks = compileTrace(entries);
  const compact = blocks.map((block) => {
    if (block.role !== "tool_result") return block;
    const omitted = `${block.text.split("\n", 1)[0]}\n[…tool result body omitted; read original entry ${block.entryId} with recall…]`;
    return {
      ...block,
      text: block.text.length <= omitted.length ? block.text : omitted,
    };
  });
  const limit = Math.floor(tokenBudget * 4);
  const baseLength = compact.reduce(
    (length, block, index) =>
      length + renderBlock(block).length + (index ? 2 : 0),
    0,
  );
  const resultCount = blocks.filter(
    (block) => block.role === "tool_result",
  ).length;
  const excerptLimit = Math.min(
    OBSERVER_TOOL_RESULT_CHARS,
    Math.floor(Math.max(0, limit - baseLength) / Math.max(1, resultCount)),
  );
  if (excerptLimit > 0) {
    for (let index = 0; index < blocks.length; index++) {
      const block = blocks[index]!;
      if (block.role !== "tool_result") continue;
      const projected = compact[index]!;
      const available = Math.min(
        OBSERVER_TOOL_RESULT_CHARS,
        projected.text.length + excerptLimit,
      );
      if (block.text.length <= available) {
        projected.text = block.text;
      } else {
        const marker = `\n[…tool result excerpt; read original entry ${block.entryId} with recall…]\n`;
        const visible = Math.max(0, available - marker.length);
        const head = Math.ceil(visible / 2);
        const tail = Math.floor(visible / 2);
        projected.text = `${block.text.slice(0, head)}${marker}${tail ? block.text.slice(-tail) : ""}`;
      }
    }
  }
  return renderTrace(compact, tokenBudget);
}

/** Render chronological trace text, retaining deterministic head and tail regions. */
export function renderTrace(
  blocks: readonly TraceBlock[],
  budgetTokens: number,
): string {
  const budgetChars = Math.max(1, Math.floor(budgetTokens)) * 4;
  const rendered = blocks.map(renderBlock);
  const complete = rendered.join("\n\n");
  if (complete.length <= budgetChars) return complete || "(none)";

  const markerFor = (first: number, last: number) =>
    `[…entries ${blocks[first]?.entryId ?? "?"} through ${blocks[last]?.entryId ?? "?"} omitted to fit the observer input…]`;
  const selectedHead: string[] = [];
  const selectedTail: string[] = [];
  let head = 0;
  let tail = rendered.length - 1;
  let used = 0;
  const sideBudget = Math.floor((budgetChars - 200) / 2);
  while (head <= tail && used + rendered[head].length + 2 <= sideBudget) {
    selectedHead.push(rendered[head]);
    used += rendered[head].length + 2;
    head++;
  }
  used = 0;
  while (tail >= head && used + rendered[tail].length + 2 <= sideBudget) {
    selectedTail.unshift(rendered[tail]);
    used += rendered[tail].length + 2;
    tail--;
  }
  const marker = markerFor(head, tail);
  return [...selectedHead, marker, ...selectedTail]
    .join("\n\n")
    .slice(0, budgetChars);
}

/** Full recallable text for one entry, produced by the shared compiler. */
export function recallTraceEntry(entry: SessionEntry) {
  const blocks = compileTraceEntry(entry);
  if (!blocks.length) return undefined;
  return {
    id: entry.id,
    timestamp: entry.timestamp,
    role: [...new Set(blocks.map((block) => block.role))].join("+"),
    text: blocks.map((block) => block.text).join("\n\n"),
  };
}

function toolResultKey(message: ContextMessage): string | undefined {
  if (message.role !== "toolResult") return undefined;
  return JSON.stringify([
    message.timestamp,
    message.toolCallId,
    message.toolName,
  ]);
}

/** Mask exact, large, already-consumed results in a disposable provider view. */
export function maskConsumedToolResults(
  messages: readonly ContextMessage[],
  contextEntries: readonly SessionEntry[],
): ContextMessage[] {
  let latestAssistantIndex = -1;
  const sourcesByKey = new Map<string, { entryId: string; index: number }[]>();
  contextEntries.forEach((entry, index) => {
    if (entry.type !== "message") return;
    if (entry.message.role === "assistant") latestAssistantIndex = index;
    const key = toolResultKey(entry.message);
    if (!key) return;
    const sources = sourcesByKey.get(key) ?? [];
    sources.push({ entryId: entry.id, index });
    sourcesByKey.set(key, sources);
  });

  const occurrences = new Map<string, number>();
  const projected = messages.map((message) => {
    const key = toolResultKey(message);
    if (!key || message.role !== "toolResult") return message;
    const occurrence = occurrences.get(key) ?? 0;
    occurrences.set(key, occurrence + 1);
    const source = sourcesByKey.get(key)?.[occurrence];
    if (!source || source.index >= latestAssistantIndex) return message;
    const text = contentText(message.content, true);
    if (text.length <= LARGE_TOOL_RESULT_CHARS) return message;
    return {
      ...message,
      content: [
        {
          type: "text" as const,
          text:
            `[Consumed ${message.toolName} output omitted from active context. ` +
            `Read original: recall({"action":"read","target":"${source.entryId}","offset":0,"scope":"lineage"})]`,
        },
      ],
    };
  });
  return projected;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
