import type { Usage } from "@earendil-works/pi-ai";
import type {
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";

import { compileTrace, renderTrace } from "./view.ts";

const PREVIOUS_OBSERVATION_TOKENS = 8_192;
const COMPACTED_TRACE_TOKENS = 16_384;
const RETAINED_TRACE_TOKENS = 8_192;
export const OBSERVATION_MAX_OUTPUT_TOKENS = 8_192;

const OBSERVER_SYSTEM_PROMPT = `You are a context observation assistant. Your task is to read a conversation between a user and an AI assistant, then produce an evolving observation following the exact format specified.

Do NOT continue the conversation. Do NOT respond to any questions in the conversation. Do NOT call tools. ONLY output the structured observation.`;

export interface ObservationInput {
  previousObservation?: string;
  compactedEntries: readonly SessionEntry[];
  retainedEntries: readonly SessionEntry[];
  focus?: string;
}

export interface ObservationResult {
  observation: string;
  usage: Usage;
}

function bounded(text: string | undefined, tokens: number): string {
  if (!text?.trim()) return "(none)";
  const limit = tokens * 4;
  if (text.length <= limit) return text;
  const marker = "\n[…middle omitted to fit observer input…]\n";
  const visible = limit - marker.length;
  return `${text.slice(0, Math.ceil(visible / 2))}${marker}${text.slice(-Math.floor(visible / 2))}`;
}

export function buildObservationPrompt(input: ObservationInput): string {
  const compacted = renderTrace(
    compileTrace(input.compactedEntries),
    COMPACTED_TRACE_TOKENS,
  );
  const retained = renderTrace(
    compileTrace(input.retainedEntries),
    RETAINED_TRACE_TOKENS,
  );
  let prompt = `<conversation>
<newly-compacted-trace>
${compacted}
</newly-compacted-trace>

<retained-tail-trace>
${retained}
</retained-tail-trace>
</conversation>

<previous-observation>
${bounded(input.previousObservation, PREVIOUS_OBSERVATION_TOKENS)}
</previous-observation>

The conversation above contains NEW evidence to incorporate into the existing observation. Rewrite the evolving observation for another LLM that will continue the work.

Use this EXACT format:

## Current task
[The user's current objective and scope]

## Active context
- [Applicable constraints, decisions, scope, and qualifications]

## Observations
- [Important results and durable facts]

## Open work
- [Unresolved tasks, blockers, and unanswered questions]

## Suggested next action
[The next concrete action]

Rules:
- Preserve applicable user constraints, decisions, scope, and qualifications.
- Incorporate newer corrections and remove stale plans.
- Reduce completed procedural narration to useful durable outcomes.
- Preserve unresolved blockers and exact paths, commands, errors, and identifiers needed to continue.
- Attach native entry IDs to important facts when they make exact recall useful.
- Merge repeated facts and avoid an exhaustive historical recap.
- The retained tail remains visible to the working agent; summarize it only when needed to interpret current intent.

Keep each section concise and self-contained. Output Markdown only.`;
  if (input.focus?.trim())
    prompt += `\n\nAdditional focus: ${bounded(input.focus, 1_024)}`;
  return prompt;
}

export async function observe(
  ctx: ExtensionContext,
  input: ObservationInput,
  signal: AbortSignal,
  routingId: string,
): Promise<ObservationResult> {
  if (!ctx.model) throw new Error("No model selected for context observation.");
  const response = await ctx.modelRegistry.complete(
    ctx.model,
    {
      systemPrompt: OBSERVER_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: buildObservationPrompt(input) }],
          timestamp: Date.now(),
        },
      ],
    },
    {
      maxTokens: Math.min(
        OBSERVATION_MAX_OUTPUT_TOKENS,
        ctx.model.maxTokens > 0
          ? ctx.model.maxTokens
          : OBSERVATION_MAX_OUTPUT_TOKENS,
      ),
      signal,
      cacheRetention: "none",
      sessionId: routingId,
    },
  );
  signal.throwIfAborted();
  if (response.stopReason !== "stop")
    throw new Error(
      `Context observation did not finish (${response.stopReason}): ${response.errorMessage ?? "no observation saved"}`,
    );
  if (response.content.some((part) => part.type === "toolCall"))
    throw new Error("Context observer attempted a tool call.");
  const observation = response.content
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n")
    .trim();
  if (!observation) throw new Error("Context observation was empty.");
  return { observation, usage: response.usage };
}
