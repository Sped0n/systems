export const ANSI_RE = /\x1b\[[0-9;]*[A-Za-z]/g;
export const CTRL_RE = /[\x00-\x08\x0b\x0c\x0e-\x1f]/g;

export const BRIEF_MAX_TOKENS = 8_192;
export const LARGE_TOOL_RESULT_CHARS = 8_000;
export const PROTECTED_RECENT_TOKENS = 8_000;
export const PROTECTED_ASSISTANT_TURNS = 4;
