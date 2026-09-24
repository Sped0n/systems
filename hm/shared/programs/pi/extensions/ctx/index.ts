import {
  SettingsManager,
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionBeforeCompactEvent,
  type SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { observe, type ObservationInput } from "./observer.ts";
import {
  COMPACT_SENTINEL,
  COMPACTION_CONTINUATION,
  COMPACTION_CONTINUATION_TYPE,
  PRESSURE_MESSAGE_TYPE,
} from "./constants.ts";
import { contextPressure, renderContextPressure } from "./pressure.ts";
import { registerRecall } from "./recall.ts";
import { maskConsumedToolResults } from "./view.ts";

interface ContextCompactionDetails {
  compactor: "ctx";
  readFiles: string[];
  modifiedFiles: string[];
}

interface CompactRequest {
  toolCallId: string;
  sessionId: string;
  phase: "requested" | "ready" | "compacting";
  userInputReceived: boolean;
}

function previousCompaction(entries: readonly SessionEntry[]) {
  return entries.findLast((entry) => entry.type === "compaction");
}

function prepareObservation(
  event: SessionBeforeCompactEvent,
): ObservationInput {
  const tailStart = event.branchEntries.findIndex(
    (entry) => entry.id === event.preparation.firstKeptEntryId,
  );
  if (tailStart < 0) throw new Error("Retained-tail boundary is missing.");
  const prior = previousCompaction(event.branchEntries);
  const compactedStart = prior
    ? event.branchEntries.findIndex(
        (entry) => entry.id === prior.firstKeptEntryId,
      )
    : 0;
  if (prior && compactedStart < 0)
    throw new Error("Previous observation boundary is missing.");
  const internalRequest =
    event.customInstructions?.startsWith(COMPACT_SENTINEL);
  return {
    userEntries: event.branchEntries.filter(
      (entry) => entry.type === "message" && entry.message.role === "user",
    ),
    previousObservation: event.preparation.previousSummary,
    compactedEntries: event.branchEntries.slice(compactedStart, tailStart),
    retainedEntries: event.branchEntries.slice(tailStart),
    focus: internalRequest ? undefined : event.customInstructions,
  };
}

function compactionDetails(
  event: SessionBeforeCompactEvent,
): ContextCompactionDetails {
  return {
    compactor: "ctx",
    readFiles: [...event.preparation.fileOps.read],
    modifiedFiles: [
      ...new Set([
        ...event.preparation.fileOps.written,
        ...event.preparation.fileOps.edited,
      ]),
    ],
  };
}

export default function contextManagement(pi: ExtensionAPI) {
  registerRecall(pi);
  let pending: CompactRequest | undefined;
  let active = true;
  let generation = 0;
  let needsContinuation = false;

  function isCurrentGeneration(startedIn: number): boolean {
    return active && generation === startedIn;
  }

  function isCurrentSession(
    ctx: ExtensionContext,
    startedIn: number,
    sessionId: string,
  ): boolean {
    return (
      isCurrentGeneration(startedIn) &&
      ctx.sessionManager.getSessionId() === sessionId
    );
  }

  function continueAfterCompaction(ctx: ExtensionContext) {
    if (!ctx.isIdle() || ctx.hasPendingMessages()) return;
    pi.sendMessage(
      {
        customType: COMPACTION_CONTINUATION_TYPE,
        content: COMPACTION_CONTINUATION,
        display: false,
      },
      { deliverAs: "followUp", triggerTurn: true },
    );
  }

  // ExtensionContext does not expose Pi's live SettingsManager. Resolve the
  // same file-backed settings, including project trust, without mutating them.
  function currentPressure(ctx: ExtensionContext) {
    const usage = ctx.getContextUsage();
    if (!usage) return undefined;
    const manager = SettingsManager.create(ctx.cwd, getAgentDir(), {
      projectTrusted: ctx.isProjectTrusted(),
    });
    if (manager.drainErrors().length) return undefined;
    const settings = manager.getCompactionSettings();
    const pressure = contextPressure(
      usage.tokens,
      usage.contextWindow,
      settings.reserveTokens,
    );
    return pressure && { ...pressure, enabled: settings.enabled };
  }

  pi.registerTool({
    name: "compact",
    label: "Compact",
    description:
      "Rewrite older context into a bounded observation while preserving Pi's recent tail and lossless history. Call alone; resumes once after success unless new input takes over.",
    promptSnippet: "Compact older context and continue with the retained tail.",
    promptGuidelines: [
      "Use compact at a useful task boundary before substantial work. Avoid compacting with fresh context unless explicitly requested. If nearly done, finish directly.",
      "Call compact alone. After successful compaction, continue with the next task action; recall only missing detail.",
    ],
    parameters: Type.Object({}, { additionalProperties: false }),
    async execute(toolCallId, _params, signal, _onUpdate, ctx) {
      signal?.throwIfAborted();
      if (pending) throw new Error("A compact request is already pending.");
      const branch = ctx.sessionManager.getBranch();
      const assistant = branch.findLast(
        (entry) =>
          entry.type === "message" && entry.message.role === "assistant",
      );
      if (
        assistant?.type !== "message" ||
        assistant.message.role !== "assistant" ||
        assistant.message.content.filter((part) => part.type === "toolCall")
          .length !== 1 ||
        !assistant.message.content.some(
          (part) => part.type === "toolCall" && part.id === toolCallId,
        )
      )
        throw new Error(
          "Call compact alone in its own tool batch, after other work has completed.",
        );
      const checkpointIndex = branch.findLastIndex(
        (entry) => entry.type === "compaction",
      );
      if (checkpointIndex >= 0) {
        // The current compact call, generated continuations, and previous
        // compact attempts are not new work. Retained pre-checkpoint messages
        // must not make a freshly compacted branch eligible again either.
        const hasNewWork = branch.slice(checkpointIndex + 1).some((entry) => {
          if (entry === assistant || entry.type !== "message") return false;
          const message = entry.message;
          if (message.role === "toolResult")
            return message.toolName !== "compact";
          if (
            message.role !== "assistant" ||
            message.stopReason === "aborted" ||
            message.stopReason === "error"
          )
            return false;
          return message.content.some((part) =>
            part.type === "text"
              ? part.text.trim().length > 0
              : part.type === "toolCall" && part.name !== "compact",
          );
        });
        const pressure = currentPressure(ctx);
        // Unknown pressure must not block recovery; large new user inputs can
        // legitimately require compaction without any intervening agent work.
        if (
          !hasNewWork &&
          (pressure?.level === "low" || pressure?.level === "advisory")
        ) {
          return {
            content: [
              {
                type: "text",
                text: "Compaction skipped: the latest checkpoint is still fresh, no new assistant/tool work needs summarizing, and context pressure is below the high threshold. Continue with the existing checkpoint and the user's latest request; do not retry compact without new work or high context pressure. Manual /compact remains available.",
              },
            ],
            details: {},
          };
        }
      }
      pending = {
        toolCallId,
        sessionId: ctx.sessionManager.getSessionId(),
        phase: "requested",
        userInputReceived: false,
      };
      return {
        content: [
          {
            type: "text",
            text: "Compaction requested. After this tool batch, observational memory will be rewritten and Pi's recent tail retained.",
          },
        ],
        details: {},
        terminate: true,
      };
    },
  });

  pi.on("turn_end", (event) => {
    if (event.message.role !== "assistant" || pending?.phase !== "requested")
      return;
    const result = event.toolResults.find(
      (item) => item.toolCallId === pending!.toolCallId,
    );
    if (
      result &&
      !event.toolResults.some((item) => item.isError) &&
      event.message.stopReason !== "aborted" &&
      event.message.stopReason !== "error"
    )
      pending.phase = "ready";
    else pending = undefined;
  });

  pi.on("input", () => {
    // The TUI flushes compaction input before onComplete, but prompt preflight
    // can still be awaiting hooks/auth while isIdle() is true. Let that input
    // own resumption instead of racing it with a synthetic prompt.
    if (pending) pending.userInputReceived = true;
    needsContinuation = false;
  });

  pi.on("turn_start", () => {
    // Automatic compaction can resume the same run inline. In that case Pi is
    // already continuing and an additional follow-up would duplicate it.
    needsContinuation = false;
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (needsContinuation) {
      needsContinuation = false;
      continueAfterCompaction(ctx);
      return;
    }
    if (pending?.phase !== "ready") return;
    const request = pending;
    const startedIn = generation;
    request.phase = "compacting";
    ctx.compact({
      customInstructions: `${COMPACT_SENTINEL}${request.toolCallId}`,
      onComplete: () => {
        if (
          !active ||
          generation !== startedIn ||
          pending !== request ||
          ctx.sessionManager.getSessionId() !== request.sessionId
        )
          return;
        pending = undefined;
        if (!request.userInputReceived) continueAfterCompaction(ctx);
      },
      onError: (error) => {
        if (!active || generation !== startedIn || pending !== request) return;
        pending = undefined;
        if (ctx.hasUI)
          ctx.ui.notify(
            `Context compaction failed; history is intact: ${error.message}`,
            "error",
          );
      },
    });
  });

  pi.on("session_before_compact", async (event, ctx) => {
    const sessionId = ctx.sessionManager.getSessionId();
    const startedIn = generation;
    try {
      event.signal.throwIfAborted();
      const result = await observe(
        ctx,
        prepareObservation(event),
        event.signal,
        `${sessionId}:ctx-observer:${event.preparation.firstKeptEntryId}`,
      );
      event.signal.throwIfAborted();
      if (!isCurrentSession(ctx, startedIn, sessionId)) return { cancel: true };
      return {
        compaction: {
          summary: result.observation,
          firstKeptEntryId: event.preparation.firstKeptEntryId,
          tokensBefore: event.preparation.tokensBefore,
          usage: result.usage,
          details: compactionDetails(event),
        },
      };
    } catch (error) {
      if (!event.signal.aborted && isCurrentGeneration(startedIn) && ctx.hasUI)
        ctx.ui.notify(
          error instanceof Error ? error.message : String(error),
          "error",
        );
      // One memory format: incomplete, failed, aborted, or stale observations
      // commit nothing and never fall through to Pi's native summarizer.
      return { cancel: true };
    }
  });

  pi.on("session_compact", (event) => {
    if (pending?.phase !== "ready") return;
    needsContinuation =
      !pending.userInputReceived &&
      event.fromExtension &&
      event.reason !== "manual" &&
      !event.willRetry;
    pending = undefined;
  });
  pi.on("session_compact_failed", () => {
    pending = undefined;
    needsContinuation = false;
  });
  pi.on("session_tree", () => {
    generation++;
    pending = undefined;
    needsContinuation = false;
  });
  pi.on("session_shutdown", () => {
    generation++;
    active = false;
    pending = undefined;
    needsContinuation = false;
  });

  pi.on("context", (event, ctx) => {
    let messages = maskConsumedToolResults(
      event.messages,
      ctx.sessionManager.buildContextEntries(),
    );
    if (pi.getActiveTools().includes("compact")) {
      const pressure = currentPressure(ctx);
      const notice = pressure?.enabled ? renderContextPressure(pressure) : "";
      if (notice)
        messages = [
          ...messages,
          {
            role: "custom",
            customType: PRESSURE_MESSAGE_TYPE,
            content: notice,
            display: false,
            timestamp: Date.now(),
          },
        ];
    }
    return { messages };
  });
}
