---
name: tmux
description: Practical guidance for isolated tmux sessions for long-running commands, interactive CLIs, monitors, debuggers, and agent-owned background work. Use when running idf.py monitor, serial logs, test watchers, REPLs, debuggers, servers, or other commands that should not block the main agent turn.
---

# tmux

Concise guidance for using tmux as an agent-owned terminal multiplexer without interfering with the user's tmux sessions.

## Purpose and Triggers

- Use for long-running commands, interactive CLIs, monitors, debuggers, REPLs, servers, and log watchers.
- Use when foreground execution would block progress or lose useful output.
- Use when a command needs later capture, interrupt, or cleanup.
- Keep agent sessions isolated from user sessions by default.

## Decision Order

1. Decide whether the command should run in foreground or background tmux.
2. Use a private opencode tmux socket path unless the user explicitly asks to use their tmux server.
3. Use `opencode-*` session names and one purpose per session.
4. Capture bounded output; do not stream forever.
5. Kill sessions when no longer needed, unless intentionally leaving them for the user.

## Workflow

1. Create `${OPENCODE_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/opencode-tmux-sockets}`.
2. Set `SOCKET="$OPENCODE_TMUX_SOCKET_DIR/opencode.sock"`.
3. Start sessions with `tmux -S "$SOCKET" new-session -d -s opencode-<purpose> ...`.
4. Capture output with `tmux -S "$SOCKET" capture-pane -p -J -t opencode-<purpose>:0.0 -S -200`.
5. Tell the user the socket path and session name when leaving a session running.
6. Kill the session when validation is complete.

## Topics

| Topic | Guidance | Reference |
| --- | --- | --- |
| Isolation | Separate user and agent tmux sessions with private socket paths | [references/isolation.md](references/isolation.md) |
| Long-Running Commands | Start, capture, interrupt, and clean up background commands | [references/long-running.md](references/long-running.md) |
| Interactive Tools | Send keystrokes safely and wait for prompts | [references/interactive-tools.md](references/interactive-tools.md) |
| Agent Sessions | Rules for tmux-hosted worker agents or nested opencode sessions | [references/agent-sessions.md](references/agent-sessions.md) |

## References

- Helper scripts live under `scripts/` and use `OPENCODE_TMUX_SOCKET_DIR`.
- Adapted from Mitsuhiko's tmux skill idea, with opencode-specific socket/session naming.
