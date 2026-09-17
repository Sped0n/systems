import {
  sessionEntryToContextMessages,
  type SessionEntry,
} from "@earendil-works/pi-coding-agent";

import { sanitize } from "./sanitize.ts";

const OBSERVER_TOOL_RESULT_CHARS = 2_000;
export const LARGE_TOOL_RESULT_CHARS = 8_000;

export type TraceRole =
  | "user"
  | "assistant"
  | "tool_call"
  | "tool_result"
  | "other";

export interface TraceBlock {
  entryId: string;
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

/** Lower one native entry into the shared, role-aware trace representation. */
export function compileTraceEntry(entry: SessionEntry): TraceBlock[] {
  if (entry.type === "branch_summary") {
    return entry.summary
      ? [{ entryId: entry.id, role: "other", text: sanitize(entry.summary) }]
      : [];
  }
  if (entry.type !== "message") return [];
  const message = entry.message;
  if (message.role === "bashExecution") {
    if (message.excludeFromContext) return [];
    return [
      {
        entryId: entry.id,
        role: "tool_result",
        text: sanitize(`$ ${message.command}\n${message.output}`),
      },
    ];
  }
  if (
    message.role === "compactionSummary" ||
    message.role === "branchSummary"
  ) {
    return [
      { entryId: entry.id, role: "other", text: sanitize(message.summary) },
    ];
  }
  if (message.role === "toolResult") {
    if (isRecallTool(message.toolName)) return [];
    const text = contentText(message.content, true);
    return text
      ? [
          {
            entryId: entry.id,
            role: "tool_result",
            text: `${message.toolName}${message.isError ? " error" : " result"}\n${text}`,
          },
        ]
      : [];
  }
  if (message.role === "user") {
    const text = contentText(message.content);
    return text ? [{ entryId: entry.id, role: "user", text }] : [];
  }
  if (message.role !== "assistant") return [];

  const blocks: TraceBlock[] = [];
  const text = contentText(message.content);
  if (text) blocks.push({ entryId: entry.id, role: "assistant", text });
  for (const part of message.content) {
    if (part.type !== "toolCall" || isRecallTool(part.name)) continue;
    blocks.push({
      entryId: entry.id,
      role: "tool_call",
      text: `${part.name}(${JSON.stringify(conciseArguments(part.name, part.arguments))})`,
    });
  }
  return blocks;
}

export function compileTrace(entries: readonly SessionEntry[]): TraceBlock[] {
  return entries.flatMap(compileTraceEntry);
}

function observerBlock(block: TraceBlock): string {
  let text = block.text;
  if (
    block.role === "tool_result" &&
    text.length > OBSERVER_TOOL_RESULT_CHARS
  ) {
    const marker = `\n[…tool result clipped; read original entry ${block.entryId} with recall…]`;
    text = `${text.slice(0, OBSERVER_TOOL_RESULT_CHARS - marker.length)}${marker}`;
  }
  return `[entry ${block.entryId}; ${block.role}]\n${text}`;
}

/** Render chronological trace text, retaining deterministic head and tail regions. */
export function renderTrace(
  blocks: readonly TraceBlock[],
  budgetTokens: number,
): string {
  const budgetChars = Math.max(1, Math.floor(budgetTokens)) * 4;
  const rendered = blocks.map(observerBlock);
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
    role: [...new Set(blocks.map((block) => block.role))].join("+"),
    text: blocks.map((block) => block.text).join("\n\n"),
  };
}

/** Mask exact, large, already-consumed results in a disposable provider view. */
export function maskConsumedToolResults(
  messages: readonly ContextMessage[],
  contextEntries: readonly SessionEntry[],
): ContextMessage[] {
  let latestAssistantIndex = -1;
  const sourceByMessage = new Map<
    ContextMessage,
    { entry: SessionEntry; index: number }
  >();
  contextEntries.forEach((entry, index) => {
    if (entry.type === "message" && entry.message.role === "assistant")
      latestAssistantIndex = index;
    for (const message of sessionEntryToContextMessages(entry))
      sourceByMessage.set(message, { entry, index });
  });

  let changed = false;
  const projected = messages.map((message) => {
    if (message.role !== "toolResult") return message;
    const source = sourceByMessage.get(message);
    if (
      !source ||
      source.index >= latestAssistantIndex ||
      source.entry.type !== "message" ||
      source.entry.message !== message
    )
      return message;
    const text = contentText(message.content, true);
    if (text.length <= LARGE_TOOL_RESULT_CHARS) return message;
    changed = true;
    return {
      ...message,
      content: [
        {
          type: "text" as const,
          text:
            `[Consumed ${message.toolName} output omitted from active context. ` +
            `Read original: recall({"action":"read","target":"${source.entry.id}","offset":0,"scope":"lineage"})]`,
        },
      ],
    };
  });
  return changed ? projected : [...messages];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
