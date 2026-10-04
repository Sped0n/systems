# Read-only Git Tool

`rogt` provides structured repository inspection to ordinary Pi sessions,
`pcommit`, and `/review`. It runs Git directly in the session's working directory
without a shell or arbitrary command-line arguments.

## Operations

All operations accept optional `paths`: literal repository paths, not globs.

| Operation | Fields                                  | Default behavior                                   |
| --------- | --------------------------------------- | -------------------------------------------------- |
| `status`  | `paths`                                 | Short branch status, including all untracked files |
| `diff`    | `staged`, `revision`, `paths`, `format` | Unstaged working-tree diff                         |
| `log`     | `revision`, `paths`, `limit`, `skip`    | Most recent 10 commits                             |
| `show`    | `revision`, `paths`, `format`           | HEAD commit and patch                              |

`diff` with `staged: true` compares the index to HEAD, or to the supplied
revision. Use a revision range such as `main...HEAD` for branch comparisons.
`show` accepts `revision:path` to read a historical file without checking it out.
`format` is `patch` (default), `stat`, or `names`. Log `limit` is 1–100 and `skip`
is 0–100000. Optional fields accept `null` to use their defaults. Fields unrelated
to the selected operation are ignored, allowing providers that fill every schema
property to call each operation successfully.

Examples:

```json
{"operation":"diff","staged":true,"paths":["src/auth.ts"]}
{"operation":"diff","revision":"main...HEAD","format":"stat"}
{"operation":"log","limit":10,"skip":10}
{"operation":"show","revision":"HEAD:src/auth.ts"}
```

## Boundaries

Git pagers, external diff helpers, text conversion, filesystem monitors, and
signature verification are disabled. Optional index refresh writes are disabled,
and inherited Git config injections and diff-helper environment variables are
removed. Lazy fetching of missing objects is disabled. This is an inspection
tool, not an OS sandbox.

Output is truncated to Pi's standard 2000 lines or 50KB, with an explicit notice.
Narrow queries by paths or revisions, use summary formats, or paginate logs.
Commands have a 30-second timeout and a 1MB capture limit; exceeding either is an
error. Cancellation and Git failures propagate as tool errors. No full-output
files are written.
