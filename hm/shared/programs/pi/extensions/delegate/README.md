# Delegate

`delegate` is a narrow model tool for moving noisy factual investigation into a
fresh context window. It produces descriptive evidence reports rather than
open-ended agent work.

```ts
{ kind: "explore" | "bash", task: "self-contained task" }
```

- `explore` receives `read`, interceptor-controlled `bash`, project/global
  context files, and only the explicit `web` skill.
- `bash` receives interceptor-controlled `bash` and context files.
- Both use the `economy` entry from `tiers.json` in a foreground,
  non-persistent child Pi process. Sibling delegate calls from one assistant
  response execute concurrently, each in its own child process.
- Normal extension, skill, and prompt-template discovery is disabled. The child
  explicitly loads only the interceptor extension, so it cannot delegate again.
- Cancellation terminates the child process.
- The parent receives only a task-appropriate final report, bounded to 32 KiB;
  intermediate tool output remains in the child context.

The child inherits the parent's project-trust decision, so the interceptor applies
the same global and trusted-project ordered rules in print mode. It is a tool-call
guard, not an OS sandbox: an allowed Bash command can still modify files or invoke other programs.

Delegate reports have no mandatory headings. They report factual evidence,
compress noisy output, cite repository evidence as `path:line`, cite external
sources by URL, and state material failures or uncertainty.
