# Session control

`pontrol` controls persistent Pi TUI and RPC sessions through owner-only Unix
sockets. Print, JSON, and `--autistic-mode` sessions do not participate.

```sh
pontrol list [--cwd PATH] [--json]
pontrol run SESSION "Review the staged changes" [--wait] [--for 2m]
pontrol send SESSION "Focus on correctness"
pontrol send SESSION --draft --stdin < context.txt
pontrol capture SESSION [--lines 100] [--json]
pontrol capture --run RUN [--lines 100] [--json]
pontrol wait RUN [--for 2m] [--json]
```

Targets are full session IDs, unambiguous eight-character ID suffixes, or unique
session names. Ambiguous targets fail. `list` excludes the calling Pi session.
Use one quoted text argument or `--stdin`, not both. Use `--` before text that
starts with a hyphen. All commands accept `--json` and `--timeout DURATION`.
Durations use `ms`, `s`, `m`, or `h`.

- `run` requires an idle session and immediately prints a run handle. `--wait`
  prints the handle first, then waits. A second run cannot replace active work.
- `send` starts a turn when idle or steers busy work. `--draft` inserts text at
  the editor cursor without submitting it. Drafts require an available TUI editor.
- `capture SESSION` reads recent visible conversation, including partial assistant
  output and tool activity. `capture --run RUN` limits output to that run.
  Captures omit model thinking and system prompts. `--lines` accepts 1 to 1000.
  Output is capped at 12,000 characters. JSON includes state, capture time, and
  truncation.
- `wait` returns the stored run result, even if the run finished before the
  client connected. It waits for retries and automatic continuations to finish.

`--timeout` limits connecting and initial acknowledgement. After acknowledgement,
`wait` has no deadline unless `--for` is set. Timeout, Ctrl-C, or disconnection
stops waiting without cancelling the run. Retry `wait` or `capture --run` with the
same handle. An uncertain submission error includes the handle for recovery;
never blindly resubmit the task.

Handles identify the owning server instance. Results survive client disconnects,
not server restarts. The server retains at most 64 completed runs, with bounded
capture text. Unknown, expired, or replaced-server handles fail explicitly.
With `run --wait --json`, stdout contains a creation record followed by a terminal
result record. Other JSON commands produce one record.

Metadata and sockets live in `$PI_CODING_AGENT_DIR/session-control/`, with directory
mode `0700` and file/socket mode `0600`. This is a same-user interface, not a security
sandbox. Reload participating Pi sessions after updating the control protocol.

| Exit status | Meaning                                    |
| ----------: | ------------------------------------------ |
|           0 | Success                                    |
|           1 | Run failed or was aborted                  |
|           2 | Invalid usage                              |
|           3 | Target missing, ambiguous, or disconnected |
|           4 | Server rejected the operation              |
|           5 | Invalid protocol data                      |
|         124 | Timeout                                    |
|         130 | Waiting interrupted                        |
