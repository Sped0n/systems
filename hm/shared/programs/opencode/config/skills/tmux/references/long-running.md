---
urls:
  - https://github.com/tmux/tmux/wiki
---

# Long-Running Commands

## Start

```sh
SOCKET_DIR=${OPENCODE_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/opencode-tmux-sockets}
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/opencode.sock"
tmux -S "$SOCKET" new-session -d -s opencode-idf-monitor -n monitor 'idf.py monitor'
```

## Capture

```sh
tmux -S "$SOCKET" capture-pane -p -J -t opencode-idf-monitor:0.0 -S -200
```

## Interrupt and Cleanup

```sh
tmux -S "$SOCKET" send-keys -t opencode-idf-monitor:0.0 C-c
tmux -S "$SOCKET" kill-session -t opencode-idf-monitor
```

## User Visibility

When leaving a session running, report both commands:

```sh
tmux -S "$SOCKET" attach -t opencode-idf-monitor
tmux -S "$SOCKET" capture-pane -p -J -t opencode-idf-monitor:0.0 -S -200
```

## Rules

- Capture recent output instead of streaming forever.
- Poll for completion text when the command has an expected prompt or success marker.
- Keep session names stable enough for later cleanup.
- Mention sessions left running in final response.
