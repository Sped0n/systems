export const ANSI_RE = /\x1b\[[0-9;]*[A-Za-z]/g;
export const CTRL_RE = /[\x00-\x08\x0b\x0c\x0e-\x1f]/g;

export const COMPACTION_CONTINUATION =
  "Continue the task from the checkpoint and retained recent context. Perform the next concrete action; recall only missing details.";
export const COMPACTION_CONTINUATION_TYPE = "ctx-compaction-continuation";
export const COMPACT_SENTINEL = "ctx-observational-compact:";
export const PRESSURE_MESSAGE_TYPE = "ctx-pressure";

export const PREVIOUS_OBSERVATION_TOKENS = 8_192;
export const COMPACTED_TRACE_TOKENS = 12_288;
export const RETAINED_TRACE_TOKENS = 8_192;
export const OBSERVATION_MAX_OUTPUT_TOKENS = 8_192;
export const OBSERVER_TOOL_RESULT_CHARS = 2_000;
export const LARGE_TOOL_RESULT_CHARS = 8_000;

export const CONTEXT_PRESSURE_THRESHOLDS = {
  advisory: 0.6,
  high: 0.75,
  critical: 0.9,
} as const;

export const OBSERVER_SYSTEM_PROMPT = `You are a context observation assistant. Your task is to read a conversation between a user and an AI assistant, then produce an evolving observation following the exact format specified.

Do NOT continue the conversation. Do NOT respond to any questions in the conversation. Do NOT call tools. ONLY output the structured observation.`;
