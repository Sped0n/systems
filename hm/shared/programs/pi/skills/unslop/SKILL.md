---
name: unslop
description: Remove formulaic prose and unnecessary code complexity while preserving meaning and behavior, using reproducible code measurements where available.
disable-model-invocation: true
metadata:
  source: "https://github.com/cursor/plugins"
  commit: "e8d856f0273b42ebafe0ec3546bd645709e7c1b0"
  adaptation: "Local router and code evaluation guidance; upstream prose body preserved without discovery frontmatter."
  evaluation_source: "https://earendil.com/posts/measuring-code-sloppiness/"
---

# Unslop

Remove unnecessary language or implementation complexity within the requested scope. Preserve meaning, required behavior, and useful rationale. Do not infer authorship from stylistic patterns or treat brevity as correctness.

## Choose the task

- For prose, documentation, or comments, read [Prose editing](references/prose.md). Apply its patterns to editable prose, not literal quotations, identifiers, required terminology, or syntax whose spelling carries meaning. Preserve necessary qualifications and factual precision.
- For code, read [Code evaluation](references/code-evaluation.md) before editing. Establish behavior checks, save a baseline measurement report, simplify, and compare results using the same scope and settings. Trace actual use before removing duplicated behavior, redundant state, or speculative abstractions.
- For mixed changes, apply both branches to their respective content. Do not change executable behavior merely to make adjacent prose sound simpler.

## Workflow

1. Establish the intended contract and a baseline. Respect audit-only requests; explicit invocation does not authorize unrelated edits or destructive operations.
2. Choose the smallest coherent simplification. Prefer deletion, reuse, or consolidation over replacing one abstraction with another.
3. Preserve safety checks, compatibility, failure handling, and ownership constraints. If a mechanism's necessity is uncertain, test a reversible removal rather than assuming it is redundant.
4. Validate meaning for prose and observable behavior for code. Compare the same deterministic code measurements before and after where supported; inspect the diff for costs those metrics miss.
5. Report the substantive changes, validation, and material tradeoffs. Stop when the requested scope is clean, not when every metric or stylistic preference is optimized.

The prose reference preserves the body of Cursor's `pstack/skills/unslop/SKILL.md` at the revision recorded above. The code workflow is a local SlopCodeBench-style adaptation of the Earendil article's formulas, not the official benchmark or its calibrated evaluator.
