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

  function continueAfterCompaction() {
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
  function compactionSettings(ctx: ExtensionContext) {
    const manager = SettingsManager.create(ctx.cwd, getAgentDir(), {
      projectTrusted: ctx.isProjectTrusted(),
    });
    if (manager.drainErrors().length) return undefined;
    return manager.getCompactionSettings();
  }

  pi.registerTool({
    name: "compact",
    label: "Compact",
    description:
      "Rewrite older context into a bounded observation while preserving Pi's recent tail and lossless history. Call alone; continues exactly once after success.",
    promptSnippet: "Compact older context and continue with the retained tail.",
    promptGuidelines: [
      "Use compact at a useful task boundary before substantial work. Avoid compacting with fresh context unless explicitly requested. If nearly done, finish directly.",
      "Call compact alone. After successful compaction, continue with the next task action; recall only missing detail.",
    ],
    parameters: Type.Object({}, { additionalProperties: false }),
    async execute(toolCallId, _params, signal, _onUpdate, ctx) {
      signal?.throwIfAborted();
      if (pending) throw new Error("A compact request is already pending.");
      const assistant = ctx.sessionManager
        .getBranch()
        .findLast(
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
      pending = {
        toolCallId,
        sessionId: ctx.sessionManager.getSessionId(),
        phase: "requested",
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

  pi.on("turn_start", () => {
    // Automatic compaction can resume the same run inline. In that case Pi is
    // already continuing and an additional follow-up would duplicate it.
    needsContinuation = false;
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (needsContinuation) {
      needsContinuation = false;
      continueAfterCompaction();
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
        continueAfterCompaction();
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
      event.fromExtension && event.reason !== "manual" && !event.willRetry;
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
      const usage = ctx.getContextUsage();
      const settings = compactionSettings(ctx);
      const pressure =
        usage && settings?.enabled
          ? contextPressure(
              usage.tokens,
              usage.contextWindow,
              settings.reserveTokens,
            )
          : undefined;
      if (pressure)
        messages = [
          ...messages,
          {
            role: "custom",
            customType: PRESSURE_MESSAGE_TYPE,
            content: renderContextPressure(pressure),
            display: false,
            timestamp: Date.now(),
          },
        ];
    }
    return { messages };
  });
}
