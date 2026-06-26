---
urls:
  - https://github.com/mitsuhiko/agent-stuff/tree/main/skills/tmux
---

# Interactive Tools

## Sending Input Safely

- Prefer literal sends for user/input text: `send-keys -l -- "$text"`.
- Send Enter separately when needed.
- Use control keys explicitly: `C-c`, `C-d`, `C-z`, `Escape`.
- Quote shell commands carefully; avoid accidental local expansion before tmux receives input.

## Examples

```sh
tmux -S "$SOCKET" send-keys -t opencode-gdb:0.0 -- 'set pagination off' Enter
tmux -S "$SOCKET" send-keys -t opencode-gdb:0.0 C-c
tmux -S "$SOCKET" send-keys -t opencode-python:0.0 -l -- 'print("ready")'
tmux -S "$SOCKET" send-keys -t opencode-python:0.0 Enter
```

## Waiting for Prompts

Use `scripts/wait-for-text.sh` with the private socket path:

```sh
scripts/wait-for-text.sh -S "$SOCKET" -t opencode-python:0.0 -p '^>>>' -T 15 -l 4000
```

## Tool Notes

- For Python REPLs, prefer `PYTHON_BASIC_REPL=1 python3 -q` so send/capture behavior stays simple.
- For debuggers, disable paging where possible.
- For TUI apps, capture output may be less reliable; prefer CLIs with plain output when possible.
