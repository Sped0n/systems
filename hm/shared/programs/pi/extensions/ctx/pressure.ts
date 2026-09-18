import { CONTEXT_PRESSURE_THRESHOLDS } from "./constants.ts";

export type ContextPressureLevel = keyof typeof CONTEXT_PRESSURE_THRESHOLDS;

export interface ContextPressure {
  level: ContextPressureLevel;
  usedTokens: number;
  budgetTokens: number;
  remainingTokens: number;
  ratio: number;
}

export function contextPressure(
  usedTokens: number | null | undefined,
  contextWindow: number,
  reserveTokens: number,
): ContextPressure | undefined {
  const budgetTokens = contextWindow - reserveTokens;
  if (
    usedTokens == null ||
    !Number.isFinite(usedTokens) ||
    usedTokens < 0 ||
    !Number.isFinite(budgetTokens) ||
    budgetTokens <= 0
  )
    return undefined;
  const ratio = usedTokens / budgetTokens;
  const level = (
    Object.entries(CONTEXT_PRESSURE_THRESHOLDS) as [
      ContextPressureLevel,
      number,
    ][]
  ).findLast(([, threshold]) => ratio >= threshold)?.[0];
  if (!level) return undefined;
  return {
    level,
    usedTokens,
    budgetTokens,
    remainingTokens: Math.max(0, budgetTokens - usedTokens),
    ratio,
  };
}

export function renderContextPressure(pressure: ContextPressure): string {
  const advice = {
    advisory:
      "Context pressure is advisory. Do not compact solely because this notice is present; plan toward a coherent boundary if substantial work remains.",
    high: "Context pressure is high. Call compact alone at the next coherent boundary if substantial work remains; finish directly if nearly done.",
    critical:
      "Context pressure is critical. Call compact alone now unless the task can be finished immediately.",
  }[pressure.level];
  return `<context-pressure level="${pressure.level}" used-tokens="${Math.round(pressure.usedTokens)}" budget-tokens="${Math.round(pressure.budgetTokens)}" remaining-tokens="${Math.round(pressure.remainingTokens)}" usage="${(pressure.ratio * 100).toFixed(1)}%">
${Math.round(pressure.remainingTokens).toLocaleString("en-US")} estimated tokens remain before automatic compaction. ${advice}
</context-pressure>`;
}
