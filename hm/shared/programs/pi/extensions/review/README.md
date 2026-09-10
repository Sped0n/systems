# Review Extension

`/review [instructions]` starts a code review on a separate branch of the
current Pi conversation, using the currently selected model and thinking level.
The review uses normal Pi streaming and tool UI. Use
`/end-review` to return to the original conversation position and insert the
complete report there.

## Usage

```text
/review
/review the changes since main
/review commit a3b7f21, focusing on cancellation behavior
/review branch feature/auth against main
/review main...feature/auth, focusing on authorization
/review src/auth and focus on authorization boundaries
/end-review
```

The review policy is maintained separately in `review-prompt.txt`; the extension
renders its session context and free-form review instructions into that template.
Everything after `/review` is passed verbatim as review instructions. It may
specify a Git scope, a review focus, or both. When no scope is given, the
reviewer examines staged, unstaged, and untracked changes. A bare `/review`
fails early when there are no uncommitted changes.

The reviewer starts from the problem and constraints, considers the simplest
viable approach within the repository, then evaluates the changes against it.
Design findings require concrete correctness, ownership, or maintenance benefits,
with compatibility and migration costs accounted for—not merely a preferred
alternative implementation. It applies both correctness/security and structural
quality lenses, including error recovery, feature gates, operational breakage,
canonical ownership, and opportunities to remove whole categories of complexity.

## Conversation Branch

Starting a review appends a non-message anchor at the exact current tree
position, derives a bounded brief from the implementation conversation, and
navigates to a branch labelled `code-review` near the beginning of the session.
The review branch receives the brief and repository instructions but does not
inherit the implementation branch's tool-call history.

The review uses ordinary Pi agent turns, so its reads, searches, Git inspection,
streaming, and Ctrl+C interruption use native Pi behavior. A dim widget remains
visible while on the branch:

```text
Review session · /end-review to return
```

`/end-review` requires the agent to be idle and is shown in autocomplete only
while a review is active. It accepts only a final assistant message with a
successful stop reason, returns to the exact origin anchor without summarizing
the review branch, restores the previous active tools, and inserts the report as
a rendered `review-result` message. If the review was interrupted before
producing a complete response, it reports that no complete report was
available. Pi does not support unregistering commands, so manually typing
`/end-review` outside a review remains valid and reports `No review is active.`

## Tools and Git Scope

Only `read` and `bash` are active on the review branch. A scoped interceptor
rule group denies Bash by default and permits only `git status`, `git diff`,
`git log`, `git show`, and `rg --no-config`; later rules reject output
redirection and execution-capable flags. The previous tool set is restored and
the runtime rules are removed on return.

Pi's Bash tool bounds command output. The reviewer can narrow a large diff by
revision or path and can inspect files in locally available commits and branches
without checking them out. It does not fetch remote refs. Branch instructions
should name their comparison base when it is not obvious, for example `branch
feature/auth against main`.

The conversation branch shares the working tree with the implementation branch;
it is not a filesystem snapshot. Mutation tools are disabled, and Bash is
restricted by the scoped interceptor rules described above.

## Rubric sources

The review policy draws on [agent-stuff's review rubric](https://github.com/mitsuhiko/agent-stuff/blob/main/extensions/review.ts)
and [Thermos's correctness and code-quality reviews](https://github.com/cursor/plugins/tree/main/thermos).
It uses Pi's direct, task-oriented instruction style and evaluates alternatives
from the underlying problem and repository constraints.

Both review lenses run in the existing local review session. The policy does not
require upstream subagent orchestration, PR-discussion access, blanket fail-fast
behavior, or file-size-based rejection. Findings require concrete impact; the
report retains this extension's concise verdict and no-findings contract.
