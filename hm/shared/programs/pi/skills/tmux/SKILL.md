---
name: tmux
description: Run isolated Pi-owned tmux sessions for interactive CLIs, monitors, debuggers, servers, and other long-running work.
metadata:
  source: "https://github.com/mitsuhiko/agent-stuff"
  commit: "13bc8f87970bec8830aab0f1c0487d35aa7c0917"
---

Use tmux when foreground execution would block progress or an interactive program needs later input, capture, interruption, or cleanup. Keep Pi sessions separate from the user's server.

```bash
SOCKET_DIR="${PI_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/pi-tmux-sockets}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/pi.sock"
SESSION="pi-<purpose>"
TMUX_CONFIG="${PI_TMUX_CONFIG:-/dev/null}"
PI_TMUX_SHELL="${PI_TMUX_SHELL:-$(command -v bash) --noprofile --norc}"
TMUX=(tmux -f "$TMUX_CONFIG" -S "$SOCKET")
PANE_ID="$("${TMUX[@]}" new-session -d -P -F '#{pane_id}' -e "PATH=$PATH" -s "$SESSION" -n shell "$PI_TMUX_SHELL")"
"${TMUX[@]}" send-keys -t "$PANE_ID" -- 'command' Enter
"${TMUX[@]}" capture-pane -p -J -t "$PANE_ID" -S -200
```

`-f /dev/null` keeps Pi-owned servers independent of the user's tmux configuration. The default Bash process uses `--noprofile --norc` to skip user-shell configuration, keeping Pi commands out of Atuin and other shell history integrations. Each new pane receives the caller's current `PATH`; other environment variables come from the isolated tmux server. Set `PI_TMUX_CONFIG` or `PI_TMUX_SHELL` only when the task deliberately needs that configuration; either can activate user integrations. The tmux config and server environment are established when the server first starts, so replace an existing server to apply broader changes.

Use short `pi-<purpose>` names. Target the captured pane ID; never assume `:0.0`, because alternate configs may change window and pane base indexes. Immediately after starting a session, give the user its attach command: `tmux -f "$TMUX_CONFIG" -S "$SOCKET" attach -t "$SESSION"`. Capture bounded history and clean up after validation with `tmux -f "$TMUX_CONFIG" -S "$SOCKET" kill-session -t "$SESSION"`.

Use `bash scripts/wait-for-text.sh -S "$SOCKET" -t "$PANE_ID" -p '<prompt>'` to synchronize with an interactive prompt, and `bash scripts/find-sessions.sh --all` to inspect Pi-owned sockets.
