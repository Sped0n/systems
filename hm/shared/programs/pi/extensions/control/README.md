# Session Control

Pi starts an owner-only local control server for persistent TUI and RPC
sessions. Print, JSON, and `--autistic-mode` sessions do not participate. The
server adds no model tools or system-prompt instructions.

`pi-control` is a small asynchronous text bridge for Pi sessions, shells, and
editors:

```text
pi-control list [--cwd PATH] [--json]
pi-control send TARGET [--message TEXT | --stdin] [--json]
pi-control paste TARGET [--message TEXT | --stdin] [--json]
pi-control last TARGET [--json]
```

Targets are exact session IDs or unique session names. Duplicate names fail
rather than selecting an arbitrary session.

- `list` reports reachable sessions and can filter by canonical working
  directory.
- `send` delivers a visible session message and returns after acceptance. It
  starts a turn when the target is idle and steers the current run when busy.
- `paste` inserts text at the target editor cursor without sending it or
  triggering a model turn.
- `last` returns the latest complete assistant text without making a model
  request.

Use `--stdin` for multiline text. `--json` produces stable one-record output.
All operations open one socket, receive one response, and close it; there are no
waits, subscriptions, or background client processes.

Discovery metadata and Unix sockets live in
`$PI_CODING_AGENT_DIR/session-control/`. The directory is mode `0700`; metadata
and sockets are mode `0600`. This is a same-user local interface, not a security
sandbox: any process running as the owner can instruct or paste into a
participating Pi.

Exit statuses:

| Status | Meaning |
| ---: | --- |
| 0 | Success |
| 2 | Invalid usage |
| 3 | Target missing, ambiguous, or unreachable |
| 4 | Server rejected the operation |
| 5 | Invalid control protocol data |
| 124 | Timeout |
