import type { SessionEntry } from "@earendil-works/pi-coding-agent";

export const REMINDER_TYPE = "ctx-reminder";
const MILESTONES = [0.7, 0.85, 0.95] as const;
const ADVICE = [
  "Consider checkpointing before another substantial step; finish directly if nearly done.",
  "Checkpoint at the next coherent boundary unless you can finish the task now.",
  "Checkpoint now if work remains; Pi's automatic compaction is approaching.",
];

export function cycleId(entries: readonly SessionEntry[]): string {
  return (
    entries.findLast((entry) => entry.type === "compaction")?.id ?? "initial"
  );
}

export function reminderKey(
  entries: readonly SessionEntry[],
  window: number,
  reserve: number,
): string {
  return `${cycleId(entries)}:${window}:${reserve}`;
}

/** Jumps emit only the highest newly crossed milestone; state comes from this branch. */
export function nextReminder(
  entries: readonly SessionEntry[],
  tokens: number,
  window: number,
  reserve: number,
) {
  const budget = window - reserve;
  if (
    !Number.isFinite(tokens) ||
    tokens < 0 ||
    !Number.isFinite(budget) ||
    budget <= 0
  )
    return;
  const level = MILESTONES.findLastIndex(
    (ratio) => tokens >= Math.ceil(budget * ratio),
  );
  if (level < 0) return;
  const key = reminderKey(entries, window, reserve);
  const delivered = entries.reduce((highest, entry) => {
    if (entry.type !== "custom_message" || entry.customType !== REMINDER_TYPE)
      return highest;
    const details = entry.details as
      | { key?: unknown; level?: unknown }
      | undefined;
    return details?.key === key && typeof details.level === "number"
      ? Math.max(highest, details.level)
      : highest;
  }, -1);
  if (level <= delivered) return;
  return {
    key,
    level,
    text:
      `[Context pressure: ${Math.round(MILESTONES[level] * 100)}% milestone of the pre-compaction budget.] ` +
      `${Math.round(tokens).toLocaleString("en-US")} of ${budget.toLocaleString("en-US")} tokens used. ${ADVICE[level]} ` +
      "Use respawn with a concise handoff and next action; older details remain available through recall.",
  };
}
