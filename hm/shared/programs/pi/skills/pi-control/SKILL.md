---
name: pi-control
description: Move text between live local Pi sessions or between external tools and Pi. Use when asked to list sessions, inspect another session's latest response, send a message, or paste text into a target session's editor draft.
---

# Pi Control

Use the standalone `pi-control` command through Bash. Operations are one-off and
return after the target accepts them. Use `--json` for machine-readable results.

Refresh discovery before selecting a target:

```bash
pi-control list --json
```

The current session ID is `$PI_SESSION_ID`. Treat it as the caller rather than a
target unless the user explicitly asks otherwise. Use an exact session ID after
selection. If a requested name matches multiple sessions, ask which one.

## Transfer text

Send a message immediately. An idle target starts a turn; a busy target is
steered:

```bash
pi-control send ID --message '...' --json
```

Paste text at the target editor cursor without sending it or triggering a model
turn:

```bash
pi-control paste ID --message '...' --json
```

Use `--stdin` instead of `--message` for multiline or generated text. Preserve
paste payloads exactly; do not add sender labels or instructions.

## Inspect

Use `pi-control last ID --json` for the latest complete assistant text. It is a
local read and makes no model request.

Pi control transports text. It does not delegate work, coordinate autonomous
agents, wait for completion, monitor sessions, or manage remote session state.
