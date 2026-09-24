import type { Usage } from "@earendil-works/pi-ai";
import type {
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";

import {
  COMPACTED_TRACE_TOKENS,
  OBSERVATION_MAX_OUTPUT_TOKENS,
  OBSERVER_SYSTEM_PROMPT,
  PREVIOUS_OBSERVATION_TOKENS,
  RETAINED_TRACE_TOKENS,
} from "./constants.ts";
import { compileTrace, renderObserverTrace, renderTrace } from "./view.ts";

export interface ObservationInput {
  /** Original user entries from the entire active lineage, including the retained tail. */
  userEntries: readonly SessionEntry[];
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
  // Intent is never clipped: reject an oversized request at the model boundary instead.
  const directives = renderTrace(compileTrace(input.userEntries), Infinity);
  const compacted = renderObserverTrace(
    input.compactedEntries,
    COMPACTED_TRACE_TOKENS,
  );
  const retained = renderObserverTrace(
    input.retainedEntries,
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

Regenerate active instructions from original user evidence and update the working-state checkpoint. Another model will use the result to continue the work.

Use this exact format:

## Active instructions
- [Durable constraints and current task requirements, with native entry IDs. Quote consequential user wording exactly.]

## Decisions and current state
- [Decisions, completed outcomes, durable facts, and implementation progress, with native entry IDs. Historical choices are revisable state, not user mandates.]

## Open work
- [Unresolved tasks, blockers, and unanswered questions]

## Next action
[The next concrete action]

Rules:
- Rebuild intent from chronological <user-directive-evidence>, including retained-tail corrections. Generated continuations are excluded by entry provenance. The previous observation is a fallible working-state checkpoint, not authoritative intent; recover applicable instructions it omitted regardless of its format.
- Preserve instruction strength, scope, conditions, and qualifications. Quote the shortest sufficient original wording for prohibitions, permissions, scope boundaries, and ambiguous preferences. "Don't care about X" is not "Do not modify X". Questions and assistant interpretations are not user mandates.
- Keep durable constraints until the user supersedes them; a task or phase change alone does not revoke them. Update the current objective from the latest request, including discussion versus implementation. Mark uncertain applicability and retain the source for clarification.
- Reconcile tasks against actions and results. Move completed requests to outcomes, retaining constraints on the resulting behavior. A proposal is not completion. Retire superseded plans; historical implementation choices remain revisable when the user asks to reconsider them.
- Preserve one-time authorization scope and consumption. Performing the authorized operation consumes permission; a checkpoint or similar task does not renew it. If uncertain, retain the original wording and require clarification before consequential action.
- Keep unresolved blockers and exact paths, commands, errors, identifiers, measurements, and wording needed to resume. Include timestamps for consequential corrections or decisions and whenever chronology matters. Link important facts to native entry IDs.
- Tool excerpts and omitted ranges are incomplete evidence: retain recall pointers for unresolved details. Merge repetition and replace procedural narration with outcomes. The retained tail stays visible; summarize it only to clarify current intent.

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
  const prompt = buildObservationPrompt(input);
  const maxTokens = Math.min(
    OBSERVATION_MAX_OUTPUT_TOKENS,
    ctx.model.maxTokens > 0
      ? ctx.model.maxTokens
      : OBSERVATION_MAX_OUTPUT_TOKENS,
  );
  // Match Pi's approximate text accounting; provider overflow still cancels safely.
  const estimatedInputTokens = Math.ceil(
    (OBSERVER_SYSTEM_PROMPT.length + prompt.length) / 4,
  );
  if (estimatedInputTokens + maxTokens > ctx.model.contextWindow)
    throw new Error(
      "Context observer input exceeds the selected model's context window; original user evidence was not truncated. Select a larger-context model and retry.",
    );
  const response = await ctx.modelRegistry.complete(
    ctx.model,
    {
      systemPrompt: OBSERVER_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: prompt }],
          timestamp: Date.now(),
        },
      ],
    },
    {
      maxTokens,
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
