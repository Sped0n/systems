# Read-only Git Tool

`rogt` provides read-only Git repository inspection.

## Operations

- `status`: short branch status with all untracked files.
- `diff`: unstaged changes by default; `staged: true` compares the index to HEAD
  or `revision`. Revision ranges such as `main...HEAD` are supported.
- `log`: recent commits; `limit` defaults to 10 (1–100), `skip` to 0 (0–100000).
- `show`: HEAD by default; `revision:path` reads a historical file.

`paths` are literal repository paths, not globs. Diff/show accept `format`:
`patch` (default), `stat`, or `names`. Optional fields accept `null` for defaults;
fields unrelated to the operation are ignored.

## Boundaries

Git runs without a shell, arbitrary options, pagers, external diff/textconv
helpers, fsmonitor, signature verification, index refresh writes, or lazy fetches.
Inherited Git config injections and diff-helper variables are removed. This is
an inspection tool, not an OS sandbox.

Output is capped at 2000 lines or 50KB with a truncation notice; narrow queries or
paginate logs. Commands fail after 30 seconds or 1MB of captured output.
Cancellation and Git errors propagate. No full-output files are written.
