---
urls:
  - https://github.com/mitsuhiko/agent-stuff/tree/main/skills/tmux
  - https://github.com/tmux/tmux/wiki
---

# Tmux Isolation

## Separation Model

- User sessions normally live on tmux's default socket.
- Agent sessions use a private socket path with `tmux -S`.
- Agent-owned session names begin with `opencode-`.
- This gives two layers of separation: different tmux server/socket and explicit session naming.

## Default Socket

```sh
SOCKET_DIR=${OPENCODE_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/opencode-tmux-sockets}
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/opencode.sock"
```

## Rules

- Always pass `-S "$SOCKET"` for agent-owned sessions.
- Do not attach to or kill sessions on the user's default tmux server unless explicitly asked.
- Do not rely on custom user tmux config for agent sessions.
- Use short slug-like names: `opencode-idf-monitor`, `opencode-gdb`, `opencode-test-watch`.
- Keep one purpose per session.

## Inspecting Sessions

```sh
tmux -S "$SOCKET" list-sessions
tmux -S "$SOCKET" list-panes -a
```

Use `scripts/find-sessions.sh --all` to scan known opencode sockets.
