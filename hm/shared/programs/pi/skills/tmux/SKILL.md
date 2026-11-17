---
name: tmux
description: "Remote control Pi-owned tmux sessions for builds, debuggers, REPLs, serial monitors, and other long-running work."
metadata:
  source: "https://github.com/mitsuhiko/agent-stuff"
  commit: "13bc8f87970bec8830aab0f1c0487d35aa7c0917"
  reference: "https://www.superlogical.com/rex/docs/automate/cli"
---

# tmux skill

Use tmux as a programmable terminal multiplexer for interactive work. Keep agent
sessions separate from the user's tmux. Use native tmux directly or the optional
Python helper `scripts/control.py` to control sockets, sessions, windows, and panes.

Set `CTL` to the absolute path of `scripts/control.py` beside this skill file.
The executable helper requires Python 3.10+, tmux, and POSIX `grep`.

## Quickstart (isolated socket)

```bash
SOCKET_NAME=firmware
PANE=$("$CTL" --socket "$SOCKET_NAME" run --session work --window build -- make)
"$CTL" --socket "$SOCKET_NAME" info "$PANE"                 # copy/paste attach command
"$CTL" --socket "$SOCKET_NAME" capture "$PANE" --lines 200 # watch output
"$CTL" --socket "$SOCKET_NAME" wait "$PANE" --for 5m       # real process exit status
"$CTL" --socket "$SOCKET_NAME" close "$PANE"               # clean up after inspection
```

After starting a terminal, **always give the user the copy/paste attach command**
from `info`. Repeat it at the end of the tool loop if the terminal is still running.
Also provide a one-shot capture command when useful; do not assume the user
remembers the socket or target.

## Socket convention

- Choose a short socket name with `--socket NAME`. Different names isolate work;
  explicitly using the same name shares that server with other agents.
- Without the flag, the helper uses `pi-$PI_SESSION_ID`. Without that identity,
  supply a name; there is no shared `standalone` fallback.
- Sockets live in `PI_TMUX_SOCKET_DIR`, default `/tmp/pi-tmux-UID/`. The directory
  must be owned by the current user and mode 0700. The short default also works
  around macOS Unix-socket path limits.
- The helper always supplies `-S` and `-f /dev/null` and clears inherited `TMUX` and
  `TMUX_PANE`. Set `PI_TMUX_CONFIG` only when the task deliberately needs another
  config. The server reads its config and most environment variables at startup.
  Choose a fresh socket to change them without interrupting work.
- Each new pane receives the caller's current `PATH`. `PI_TMUX_SHELL`
  overrides the default clean Bash. These overrides can enable user integrations.

## Targeting panes and naming

- `run --session work --window build -- COMMAND...` creates a detached window,
  creating the session if needed. The default session is `main`.
- Prefer the returned native pane ID, such as `%3`. Explicit
  `session:window.pane` addresses also work. Do not assume `:0.0`, since custom
  configs may change the base indexes. Pane IDs are scoped to a server's lifetime.
- `split PANE --direction right -- COMMAND...` adds a sibling pane. Other directions
  are `left`, `above`, and `below`.
- `info PANE --json` gives the socket path, session/window IDs, pane ID, and attach
  command. Native tmux remains available for resizing, moving, and other operations:

  ```bash
  # SOCKET is the socketPath returned by info, not just the socket name.
  env -u TMUX -u TMUX_PANE tmux -f /dev/null -S "$SOCKET" resize-pane -t "$PANE" -R 10
  ```

Keep an explicit owned socket and config on every native command. Never fall back
to the user's default server. This prevents accidental targeting; it is not an OS
security sandbox.

## Finding sessions

```bash
"$CTL" sockets
"$CTL" --socket firmware list
"$CTL" --socket firmware list --session work --json
```

`list` includes native tmux panes as well as helper-created ones. Use the window
names, commands, and working directories to rediscover builds, debuggers, and
monitors after losing context. No helper registration files are required.

## Sending input safely

```bash
"$CTL" --socket firmware send "$PANE" 'print(6 * 7)' --enter
printf 'x = 20\nprint(x + 3)\n' | "$CTL" --socket firmware send "$PANE" --stdin
"$CTL" --socket firmware send-key "$PANE" C-c
"$CTL" --socket firmware send-key "$PANE" F12 M-x Enter
```

`send` treats text as literal data, including multiline input. It adds Enter only
with `--enter`; use `send-key PANE Enter` for a bare Enter. `send-key` accepts all
native tmux key names and sequences. Commands after a creation command's `--`
execute as argv without implicit shell expansion; use an explicit clean shell
when shell syntax is required.

## Watching output

- `capture PANE` captures joined recent screen/history lines, default 200.
- `capture PANE --lines N` requests more; `--all` reads all available tmux history.
  These are alternative modes. There is no hidden character cap.
- `--ansi` preserves rendered colors. Full-screen apps redraw their screen, so a
  capture is not a complete stdout log. Keep ordinary captures bounded.
- Use timed polling for readiness rather than `tmux wait-for`, which does not
  watch pane output. Attach using the command from `info`; detach with `Ctrl+b d`
  on the default config.

## Spawning processes

- Run builds and servers with `run --window build -- make` or the program's normal
  command. Use `wait` for completion, then capture and inspect the retained output.
- Prefer LLDB when asked to debug. Start with
  `run --window debug -- lldb --no-lldbinit ./app`; wait for `\(lldb\)`, then send
  commands such as `breakpoint set --name main`, `bt`, and `frame variable`.
  For gdb, start `gdb --quiet ./app`, wait for `\(gdb\)`, and disable pagination
  with `set pagination off`. Interrupt with `C-c`; quit when finished.
- For a Python REPL, use `run -- env PYTHON_BASIC_REPL=1 python3 -q`. Always set
  `PYTHON_BASIC_REPL=1` because the enhanced console interferes with scripted input.
  Wait for `^>>>`, send literal code and Enter, and exit with `C-d`.
- `run` without a command starts `bash --noprofile --norc`.
  It preserves shell state without loading user startup files or history integrations.
- For serial monitors and other TTY apps, start the program's normal command,
  wait for readiness, then capture or send input. Rediscover the same pane later
  rather than starting another monitor. Do not access hardware without task approval.

## Synchronizing / waiting for prompts

```bash
"$CTL" --socket firmware wait "$PANE" --regex '^>>>' --for 15s --lines 4000
"$CTL" --socket firmware wait "$PANE" --text 'server ready' --for 20s --interval 500ms
"$CTL" --socket firmware wait "$PANE" --for 5m --json
```

- `--regex` preserves POSIX extended-regex semantics, including `[[:space:]]` and
  `[[:digit:]]`. `--text` matches a fixed string. Default search history is 1000
  lines; default poll interval is 500ms. Both can match old scrollback, so readiness
  is not proof of command success.
- Plain `wait` observes the pane process's exit and returns its status, including
  signals. In a persistent shell, that means the shell's exit, not an inner command.
  Supply `--for` for uncertain-duration work; otherwise waiting is unbounded.
- Timeout returns 124; interrupted waiting returns 130. Neither cancels the process.
  Wait or capture again using the existing pane; never blindly rerun the command.
- Missing panes or a lost server fail explicitly. Queries never start a replacement
  server. Rediscover targets after server replacement instead of trusting old IDs.

## Cleanup

- `close PANE` removes an exited pane after inspection. A live pane requires
  `close PANE --force`. It never kills sibling panes.
- Native `kill-session` or `kill-server` is available when all affected work is
  yours and finished. Do not kill unrelated work on an explicitly shared socket.
- Exited panes retain output and status until closed. A creation timeout may occur
  after launch; use `list` to recover rather than starting a duplicate.

## Helper: control.py

`--socket NAME`, `--timeout DURATION`, and `--json` work before or after the verb.
For `run` and `split`, put helper options before `-- COMMAND...`. Durations use
`ms`, `s`, `m`, or `h`; the per-request timeout defaults to 5s.

Human listings include headers. Successful input and cleanup commands stay quiet;
use `--json` for structured results and acknowledgements. `run --wait` prints the
pane ID first, then returns the child's status; `run --wait --json` prints one
creation record, not progress records. JSON distinguishes helper errors from a
process exiting with the same numeric status. `--help` is available on each command.
