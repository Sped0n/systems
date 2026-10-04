# Review Extension

`/review [instructions]` starts a read-only review on a separate conversation
branch, preserving the selected model and thinking level. `/end-review` returns
to the original position, restores its tools, and inserts the final report.

## Usage

```text
/review
/review main...HEAD, focusing on authorization
/review src/auth and focus on cancellation
/end-review
```

Instructions can specify scope, focus, or both. Without a scope, review covers
staged, unstaged, and untracked changes. A bare `/review` stops early when there
are no uncommitted changes. Name the comparison base when reviewing a branch.

## Behavior

- The review receives a bounded conversation brief and repository instructions,
  not the implementation branch's tool-call history.
- Only `codemode`, [`rogt`](../rogt/README.md), `read`, `grep`, `find`, and `ls`
  are active. Codemode can batch inspections or filter results; recall, Bash,
  mutation tools, and other custom tools are not active.
- Git inspection uses local refs without fetching or checking out revisions.
  The working tree is shared, not snapshotted.
- Streaming and Ctrl+C use normal Pi behavior. `/end-review` requires an idle
  agent. It returns the completed final response, or a notice if no complete
  report is available.

## Review Policy

[`review-prompt.txt`](./review-prompt.txt) owns the rubric and report format.
Reviews cover correctness, safety, and substantial maintainability regressions;
findings require concrete impact, not stylistic preferences or speculative
redesigns.

The rubric draws on [agent-stuff](https://github.com/mitsuhiko/agent-stuff/blob/main/extensions/review.ts)
and [Thermos](https://github.com/cursor/plugins/tree/main/thermos).
