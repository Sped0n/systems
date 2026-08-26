import type {
  ExtensionAPI,
  ExtensionContext,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";

export const TURN_COMPACTION_THRESHOLD_PERCENT = 90;

type TurnCompactionState = {
  sessionId: string;
  phase: "waitingForSettle" | "compacting" | "compacted";
};

class TurnCompactionCoordinator {
  private state: TurnCompactionState | undefined;
  private readonly pi: ExtensionAPI;

  constructor(pi: ExtensionAPI) {
    this.pi = pi;
  }

  register(): void {
    this.pi.on("session_start", () => this.reset());
    this.pi.on("session_shutdown", () => this.reset());
    this.pi.on("model_select", () => this.reset());
    this.pi.on("turn_end", (_event, ctx) => this.stopAtTurnBoundary(ctx));
    this.pi.on("session_compact", (event, ctx) => this.adoptPiCompaction(event, ctx));
    this.pi.on("agent_settled", (_event, ctx) => this.compactAfterSettle(ctx));
  }

  private reset(): void {
    this.state = undefined;
  }

  private stopAtTurnBoundary(ctx: ExtensionContext): void {
    if (this.state) return;

    const usagePercent = ctx.getContextUsage()?.percent;
    if (usagePercent === undefined || usagePercent === null || !Number.isFinite(usagePercent)) return;
    if (usagePercent < TURN_COMPACTION_THRESHOLD_PERCENT) return;

    this.state = {
      sessionId: ctx.sessionManager.getSessionId(),
      phase: "waitingForSettle",
    };
    if (ctx.hasUI) {
      ctx.ui.notify(
        `Context reached ${usagePercent.toFixed(1)}%; stopping for compaction.`,
        "warning",
      );
    }

    // Pi cannot compact inside an active agent run. Stop after this finalized
    // turn, then enter Pi's native compaction lifecycle from agent_settled.
    ctx.abort();
  }

  private adoptPiCompaction(event: SessionCompactEvent, ctx: ExtensionContext): void {
    const state = this.state;
    if (
      !state
      || state.phase !== "waitingForSettle"
      || state.sessionId !== ctx.sessionManager.getSessionId()
      || event.reason === "manual"
    ) {
      return;
    }

    if (event.willRetry) {
      this.state = undefined;
      return;
    }
    this.state = { ...state, phase: "compacted" };
  }

  private compactAfterSettle(ctx: ExtensionContext): void {
    const state = this.state;
    if (!state || state.sessionId !== ctx.sessionManager.getSessionId()) return;

    if (state.phase === "compacted") {
      this.finishCompaction(state);
      return;
    }
    if (state.phase !== "waitingForSettle") return;

    const compacting: TurnCompactionState = { ...state, phase: "compacting" };
    this.state = compacting;
    ctx.compact({
      onComplete: () => this.finishCompaction(compacting),
      onError: (error) => {
        if (this.state !== compacting) return;
        this.state = undefined;
        if (ctx.hasUI) ctx.ui.notify(`Compaction failed: ${error.message}`, "error");
      },
    });
  }

  private finishCompaction(expected: TurnCompactionState): void {
    if (this.state === expected) this.state = undefined;
  }
}

export default function turnCompactionExtension(pi: ExtensionAPI): void {
  new TurnCompactionCoordinator(pi).register();
}
