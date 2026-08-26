import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import turnCompactionExtension, { TURN_COMPACTION_THRESHOLD_PERCENT } from "./index.ts";

type Handler = (...args: any[]) => void;

type CompactionRequest = {
  onComplete?: () => void;
  onError?: (error: Error) => void;
};

function turnCompactionHarness() {
  const handlers = new Map<string, Handler>();
  const compactionRequests: CompactionRequest[] = [];
  const notifications: Array<{ message: string; level: string }> = [];
  let abortCount = 0;
  let contextPercent: number | null = 0;

  const pi = {
    on(name: string, handler: Handler) {
      handlers.set(name, handler);
    },
    sendUserMessage() {
      assert.fail("turn compaction must not inject a continuation prompt");
    },
  } as unknown as ExtensionAPI;
  turnCompactionExtension(pi);

  const context = {
    hasUI: true,
    ui: {
      notify(message: string, level: string) {
        notifications.push({ message, level });
      },
    },
    sessionManager: { getSessionId: () => "session-1" },
    getContextUsage: () => ({ tokens: 1, contextWindow: 1, percent: contextPercent }),
    abort: () => { abortCount += 1; },
    compact: (request: CompactionRequest) => { compactionRequests.push(request); },
  };

  return {
    handlers,
    context,
    compactionRequests,
    notifications,
    setContextPercent(percent: number | null) { contextPercent = percent; },
    get abortCount() { return abortCount; },
  };
}

test("compacts at the turn boundary without injecting a continuation prompt", () => {
  const harness = turnCompactionHarness();
  harness.setContextPercent(TURN_COMPACTION_THRESHOLD_PERCENT);

  harness.handlers.get("turn_end")!({}, harness.context);

  assert.equal(harness.abortCount, 1);
  assert.equal(harness.compactionRequests.length, 0);
  assert.match(harness.notifications[0]?.message ?? "", /stopping for compaction/);

  harness.handlers.get("agent_settled")!({}, harness.context);
  assert.equal(harness.compactionRequests.length, 1);

  harness.compactionRequests[0]?.onComplete?.();
  harness.handlers.get("turn_end")!({}, harness.context);
  assert.equal(harness.abortCount, 2);
});

test("does not interrupt a tool loop below the turn compaction threshold", () => {
  const harness = turnCompactionHarness();
  harness.setContextPercent(TURN_COMPACTION_THRESHOLD_PERCENT - 0.001);

  harness.handlers.get("turn_end")!({}, harness.context);

  assert.equal(harness.abortCount, 0);
  assert.equal(harness.compactionRequests.length, 0);
});

test("adopts Pi threshold compaction instead of compacting twice", () => {
  const harness = turnCompactionHarness();
  harness.setContextPercent(TURN_COMPACTION_THRESHOLD_PERCENT);
  harness.handlers.get("turn_end")!({}, harness.context);

  harness.handlers.get("session_compact")!({
    reason: "threshold",
    willRetry: false,
    fromExtension: false,
  }, harness.context);
  harness.handlers.get("agent_settled")!({}, harness.context);

  assert.equal(harness.compactionRequests.length, 0);
});

test("leaves overflow compaction retry to Pi", () => {
  const harness = turnCompactionHarness();
  harness.setContextPercent(TURN_COMPACTION_THRESHOLD_PERCENT);
  harness.handlers.get("turn_end")!({}, harness.context);

  harness.handlers.get("session_compact")!({
    reason: "overflow",
    willRetry: true,
    fromExtension: false,
  }, harness.context);
  harness.handlers.get("agent_settled")!({}, harness.context);

  assert.equal(harness.compactionRequests.length, 0);
});

test("clears failed compaction state so a later turn can retry", () => {
  const harness = turnCompactionHarness();
  harness.setContextPercent(TURN_COMPACTION_THRESHOLD_PERCENT);
  harness.handlers.get("turn_end")!({}, harness.context);
  harness.handlers.get("agent_settled")!({}, harness.context);

  harness.compactionRequests[0]?.onError?.(new Error("summary unavailable"));
  assert.deepEqual(harness.notifications.at(-1), {
    message: "Compaction failed: summary unavailable",
    level: "error",
  });

  harness.handlers.get("turn_end")!({}, harness.context);
  assert.equal(harness.abortCount, 2);
});
