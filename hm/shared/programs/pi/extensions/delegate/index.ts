import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { basename, join } from "node:path";

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import { getModelTier, readModelTiers, type ModelTier } from "../tier/model-tiers.ts";

const DELEGATE_OUTPUT_BYTES_MAX = 32 * 1024;
const DELEGATE_ERROR_BYTES_MAX = 32 * 1024;
const DELEGATE_JSON_LINE_BYTES_MAX = 1024 * 1024;
const DELEGATE_TASK_CHARACTERS_MAX = 32 * 1024;
const DELEGATE_KILL_GRACE_MS = 2_000;
const DELEGATE_ACTIVITY_CHARACTERS_MAX = 120;
const TRUNCATION_MARKER = "\n\n[delegate output truncated]";

export type DelegateKind = "explore" | "bash";

export interface DelegateDetails {
  kind: DelegateKind;
  exitCode: number;
  model?: string;
  stopReason?: string;
  truncated: boolean;
}

interface DelegateAssistantMessage {
  text: string;
  model?: string;
  stopReason?: string;
  errorMessage?: string;
}

type DelegateToolCallCallback = (toolName: string, args: Record<string, unknown>) => void;

export interface DelegateChildResult {
  exitCode: number;
  stderr: string;
  message?: DelegateAssistantMessage;
  protocolError?: string;
}

const DelegateParameters = Type.Object(
  {
    kind: StringEnum(["explore", "bash"] as const, {
      description: "Focused delegate role",
    }),
    task: Type.String({
      description: "Self-contained factual question or investigation scope with the needed context",
      minLength: 1,
      maxLength: DELEGATE_TASK_CHARACTERS_MAX,
    }),
  },
  { additionalProperties: false },
);

const COMMON_DELEGATE_PROMPT = [
  "You are a one-shot delegated investigator with a clean context window.",
  "Complete only the supplied task using only the available tools.",
  "Gather observable facts and report the supporting evidence.",
  "Keep every conclusion descriptive and directly supported by cited evidence.",
  "Return a direct, concise report in task-appropriate Markdown.",
  "Compress noisy tool output into material findings rather than reproducing logs.",
  "Support repository claims with path:line evidence when available.",
  "State material failures, uncertainty, or missing evidence; never invent around them.",
  "Include commands only when they are important evidence or necessary to understand the result.",
  "Do not ask follow-up questions or offer to continue the child conversation.",
].join(" ");

const DELEGATE_PROMPTS: Record<DelegateKind, string> = {
  explore: [
    COMMON_DELEGATE_PROMPT,
    "Explore code, documentation, and external sources when the task requires them.",
    "Use the web skill only for requested or genuinely necessary external facts.",
    "Prefer primary web sources and cite source URLs.",
    "Do not modify project files.",
  ].join(" "),
  bash: [
    COMMON_DELEGATE_PROMPT,
    "Run the shell commands needed to investigate or verify the task.",
    "Do not modify files unless the task explicitly requires it and the interceptor permits the command.",
  ].join(" "),
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function extractAssistantMessage(value: unknown): DelegateAssistantMessage | undefined {
  if (!isRecord(value) || value.role !== "assistant" || !Array.isArray(value.content)) return undefined;
  const text = value.content
    .filter((part): part is { type: "text"; text: string } =>
      isRecord(part) && part.type === "text" && typeof part.text === "string"
    )
    .map((part) => part.text)
    .join("")
    .trim();
  return {
    text,
    ...(typeof value.model === "string" ? { model: value.model } : {}),
    ...(typeof value.stopReason === "string" ? { stopReason: value.stopReason } : {}),
    ...(typeof value.errorMessage === "string" ? { errorMessage: value.errorMessage } : {}),
  };
}

/** Bound returned text without leaving a partial UTF-8 sequence at the cut. */
export function boundDelegateText(
  text: string,
  bytesMax = DELEGATE_OUTPUT_BYTES_MAX,
  marker = TRUNCATION_MARKER,
): { text: string; truncated: boolean } {
  const content = Buffer.from(text);
  if (content.byteLength <= bytesMax) return { text, truncated: false };
  const markerBuffer = Buffer.from(marker);
  if (bytesMax <= markerBuffer.byteLength) {
    return {
      text: content.subarray(0, bytesMax).toString("utf8").replace(/\uFFFD$/u, ""),
      truncated: true,
    };
  }
  const prefix = content
    .subarray(0, bytesMax - markerBuffer.byteLength)
    .toString("utf8")
    .replace(/\uFFFD$/u, "");
  return { text: `${prefix}${marker}`, truncated: true };
}

function appendBoundedText(current: string, addition: string, bytesMax: number): string {
  if (Buffer.byteLength(current) >= bytesMax) return current;
  return boundDelegateText(`${current}${addition}`, bytesMax, "").text;
}

function formatDelegateActivityValue(value: unknown): string {
  const singleLine = typeof value === "string" ? value.replace(/\s+/gu, " ").trim() : "";
  if (!singleLine) return "...";
  if (singleLine.length <= DELEGATE_ACTIVITY_CHARACTERS_MAX) return singleLine;
  return `${singleLine.slice(0, DELEGATE_ACTIVITY_CHARACTERS_MAX - 3)}...`;
}

export function formatDelegateToolCall(toolName: string, args: Record<string, unknown>): string {
  if (toolName === "read") return `→ read ${formatDelegateActivityValue(args.path)}`;
  if (toolName === "bash") return `→ bash $ ${formatDelegateActivityValue(args.command)}`;
  return `→ ${formatDelegateActivityValue(toolName)}`;
}

export class DelegateJsonLineParser {
  private line = "";
  private lineBytes = 0;
  private skippingOversizedLine = false;
  private readonly onToolCall?: DelegateToolCallCallback;

  message?: DelegateAssistantMessage;
  protocolError?: string;

  constructor(onToolCall?: DelegateToolCallCallback) {
    this.onToolCall = onToolCall;
  }

  push(chunk: string): void {
    const parts = chunk.split("\n");
    for (let index = 0; index < parts.length; index += 1) {
      this.append(parts[index]);
      if (index < parts.length - 1) this.finishLine();
    }
  }

  finish(): void {
    if (this.line || this.skippingOversizedLine) this.finishLine();
  }

  private append(part: string): void {
    if (this.skippingOversizedLine) return;
    const bytes = Buffer.byteLength(part);
    if (this.lineBytes + bytes > DELEGATE_JSON_LINE_BYTES_MAX) {
      this.line = "";
      this.lineBytes = 0;
      this.skippingOversizedLine = true;
      return;
    }
    this.line += part;
    this.lineBytes += bytes;
  }

  private finishLine(): void {
    if (this.skippingOversizedLine) {
      this.protocolError ??= `Delegate emitted a JSONL record larger than ${DELEGATE_JSON_LINE_BYTES_MAX} bytes`;
      this.skippingOversizedLine = false;
      return;
    }
    const line = this.line.trim();
    this.line = "";
    this.lineBytes = 0;
    if (!line) return;

    let event: unknown;
    try {
      event = JSON.parse(line);
    } catch {
      this.protocolError ??= "Delegate emitted malformed JSONL output";
      return;
    }
    if (!isRecord(event)) return;
    if (event.type === "tool_execution_start" && typeof event.toolName === "string") {
      this.onToolCall?.(event.toolName, isRecord(event.args) ? event.args : {});
      return;
    }
    if (event.type !== "message_end") return;
    const message = extractAssistantMessage(event.message);
    if (message) this.message = message;
  }
}

export function buildDelegateArguments(
  kind: DelegateKind,
  task: string,
  tier: ModelTier,
  projectTrusted: boolean,
  agentDir = getAgentDir(),
): string[] {
  const args = [
    "--mode",
    "json",
    "--print",
    "--no-session",
    projectTrusted ? "--approve" : "--no-approve",
    "--no-extensions",
    "--extension",
    join(agentDir, "extensions", "interceptor", "index.ts"),
    "--no-skills",
  ];
  if (kind === "explore") {
    args.push("--skill", join(agentDir, "skills", "web", "SKILL.md"));
  }
  args.push(
    "--no-prompt-templates",
    "--tools",
    kind === "explore" ? "read,bash" : "bash",
    "--provider",
    tier.provider,
    "--model",
    tier.model,
    "--thinking",
    tier.thinkingLevel,
    "--append-system-prompt",
    DELEGATE_PROMPTS[kind],
    `Task: ${task}`,
  );
  return args;
}

export function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
  if (currentScript && !isBunVirtualScript && existsSync(currentScript)) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }
  const executable = basename(process.execPath).toLowerCase();
  if (!/^(node|bun)(\.exe)?$/u.test(executable)) return { command: process.execPath, args };
  return { command: "pi", args };
}

export async function runDelegateChild(
  command: string,
  args: readonly string[],
  cwd: string,
  signal?: AbortSignal,
  onToolCall?: DelegateToolCallCallback,
): Promise<DelegateChildResult> {
  return await new Promise((resolve, reject) => {
    const child = spawn(command, [...args], { cwd, shell: false, stdio: ["ignore", "pipe", "pipe"] });
    const parser = new DelegateJsonLineParser(onToolCall);
    let stderr = "";
    let aborted = false;
    let killTimer: NodeJS.Timeout | undefined;
    let settled = false;

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => parser.push(chunk));
    child.stderr.on("data", (chunk: string) => {
      stderr = appendBoundedText(stderr, chunk, DELEGATE_ERROR_BYTES_MAX);
    });

    const abort = () => {
      aborted = true;
      child.kill("SIGTERM");
      killTimer = setTimeout(() => {
        if (child.exitCode === null && child.signalCode === null) child.kill("SIGKILL");
      }, DELEGATE_KILL_GRACE_MS);
      killTimer.unref();
    };
    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });

    const cleanup = () => {
      if (killTimer) clearTimeout(killTimer);
      signal?.removeEventListener("abort", abort);
    };
    child.once("error", (error) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(error);
    });
    child.once("close", (code) => {
      if (settled) return;
      settled = true;
      cleanup();
      parser.finish();
      if (aborted) {
        reject(new Error("Delegate was aborted"));
        return;
      }
      resolve({
        exitCode: code ?? 1,
        stderr: stderr.trim(),
        message: parser.message,
        protocolError: parser.protocolError,
      });
    });
  });
}

export default function delegateExtension(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "delegate",
    label: "Delegate",
    description: [
      "Delegate context-heavy factual exploration or multi-command shell investigation to a fresh economy-model context.",
      "Produce a descriptive evidence report supported by repository locations, command results, or source URLs.",
      "Use explore for code, documentation, or web research; use bash for a sequence of shell commands.",
      "The delegate returns one compressed report and has no edit, write, or nested delegation tools.",
      "Prefer direct tools for simple one-step work.",
    ].join(" "),
    promptSnippet: "Delegate context-heavy factual evidence collection through explore or bash",
    parameters: DelegateParameters,
    executionMode: "parallel",

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const task = params.task.trim();
      if (!task) {
        return {
          content: [{ type: "text", text: "Delegate task must not be empty" }],
          details: { kind: params.kind, exitCode: 1, truncated: false } satisfies DelegateDetails,
          isError: true,
        };
      }

      try {
        const tier = getModelTier(await readModelTiers(), "economy");
        const childArgs = buildDelegateArguments(
          params.kind,
          task,
          tier,
          ctx.isProjectTrusted(),
        );
        const invocation = getPiInvocation(childArgs);
        const result = await runDelegateChild(
          invocation.command,
          invocation.args,
          ctx.cwd,
          signal,
          (toolName, args) => {
            onUpdate?.({
              content: [{ type: "text", text: formatDelegateToolCall(toolName, args) }],
              details: { kind: params.kind, exitCode: -1, truncated: false } satisfies DelegateDetails,
            });
          },
        );
        const message = result.message;
        const failure = result.protocolError
          ?? (result.exitCode !== 0 ? result.stderr || `Delegate exited with status ${result.exitCode}` : undefined)
          ?? (message?.stopReason === "error" || message?.stopReason === "aborted"
            ? message.errorMessage || `Delegate stopped with ${message.stopReason}`
            : undefined)
          ?? (!message?.text ? "Delegate returned no final report" : undefined);
        const bounded = boundDelegateText(failure ?? message?.text ?? "");
        return {
          content: [{ type: "text", text: bounded.text }],
          details: {
            kind: params.kind,
            exitCode: result.exitCode,
            ...(message?.model ? { model: message.model } : {}),
            ...(message?.stopReason ? { stopReason: message.stopReason } : {}),
            truncated: bounded.truncated,
          } satisfies DelegateDetails,
          ...(failure ? { isError: true } : {}),
        };
      } catch (error) {
        const text = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text", text }],
          details: { kind: params.kind, exitCode: 1, truncated: false } satisfies DelegateDetails,
          isError: true,
        };
      }
    },

    renderCall(args, theme) {
      const preview = args.task.length > 72 ? `${args.task.slice(0, 69)}...` : args.task;
      return new Text(
        `${theme.fg("toolTitle", theme.bold("delegate "))}${theme.fg("accent", args.kind)}\n${theme.fg("dim", preview)}`,
        0,
        0,
      );
    },
  });
}
