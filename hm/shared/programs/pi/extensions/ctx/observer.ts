import type { Usage } from "@earendil-works/pi-ai";
import type {
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";

import {
  COMPACTED_TRACE_TOKENS,
  COMPACTION_CONTINUATION,
  OBSERVATION_MAX_OUTPUT_TOKENS,
  OBSERVER_SYSTEM_PROMPT,
  PREVIOUS_OBSERVATION_TOKENS,
  RETAINED_TRACE_TOKENS,
  USER_DIRECTIVE_TOKENS,
} from "./constants.ts";
import { compileTrace, renderTrace } from "./view.ts";

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
  const compactedBlocks = compileTrace(input.compactedEntries);
  const directives = renderTrace(
    compactedBlocks.filter(
      (block) =>
        block.role === "user" && block.text.trim() !== COMPACTION_CONTINUATION,
    ),
    USER_DIRECTIVE_TOKENS,
  );
  const compacted = renderTrace(compactedBlocks, COMPACTED_TRACE_TOKENS);
  const retained = renderTrace(
    compileTrace(input.retainedEntries),
    RETAINED_TRACE_TOKENS,
  );
  let prompt = `<conversation>
<user-directive-evidence>
${directives}
</user-directive-evidence>

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

Update the existing observation with the new conversation evidence. Another model will use the result to continue the work.

Use this exact format:

## Current task
[The user's current objective and scope]

## Active user directives
- [Applicable requirements, prohibitions, preferences, authorization limits, and workflow constraints. Include native entry IDs.]

## Accepted decisions
- [Current technical and product decisions. Include native entry IDs when exact recall is useful.]

## Current state
- [Important results, durable facts, and implementation progress.]

## Open work
- [Unresolved tasks, blockers, and unanswered questions]

## Suggested next action
[The next concrete action]

Rules:
- Use <user-directive-evidence> to identify genuine user intent in the newly compacted span. It excludes extension-generated continuation messages.
- Preserve every applicable user requirement, prohibition, preference, authorization limit, workflow constraint, decision, scope boundary, and qualification.
- Keep an active user directive until a later genuine user message explicitly supersedes it. A task or phase change alone does not revoke it.
- If applicability is uncertain, retain the directive with its native entry ID for exact recall.
- Apply newer corrections and remove only explicitly superseded plans. State what changed so the current state is unambiguous.
- Replace completed procedural narration with durable outcomes.
- Preserve unresolved blockers, exact paths, commands, errors, identifiers, measured values, and wording that the user may need reproduced.
- Preserve timestamps when chronology, relative dates, or the order of state changes matters.
- Add native entry IDs to important facts when exact recall may help.
- Merge repetition rather than writing an exhaustive history.
- The retained tail remains visible to the working agent. Summarize it only when needed to interpret current intent.

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
