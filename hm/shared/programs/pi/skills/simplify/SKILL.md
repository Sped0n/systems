---
name: simplify
description: Simplify code and prose while preserving required behavior and meaning, using first-principles reasoning, reversible removal experiments, and reproducible code measurements where available.
disable-model-invocation: true
metadata:
  source: "https://github.com/cursor/plugins"
  commit: "9b93e81fb2921b9263d9463c15bafeabfe3903aa"
  adaptation: "Local simplification workflow and Lizard measurement guidance; upstream prose body preserved in references/prose.md without discovery frontmatter."
---

# Simplify

Start from required outcomes, inputs, constraints, and failure behavior rather than the existing wording or architecture. Separate actual requirements from implementation assumptions. Remove unnecessary language or mechanisms only when doing so makes the whole system simpler, not merely moves complexity elsewhere. Preserve meaning, required behavior, and useful rationale; do not infer authorship from stylistic patterns or treat brevity as correctness.

## Choose the task

- For prose, documentation, or comments, read [Prose editing](references/prose.md). Apply its patterns to editable prose, not literal quotations, identifiers, required terminology, or syntax whose spelling carries meaning. Preserve necessary qualifications and factual precision.
- For code, read [Code evaluation](references/code-evaluation.md) when measuring complexity or size. Establish behavior checks and relevant baseline measurements before editing. Trace actual use before removing duplicated behavior, redundant state, or speculative abstractions.
- For mixed changes, apply both branches to their respective content. Do not change executable behavior merely to make adjacent prose sound simpler.

## Workflow

1. Establish the intended contract and a baseline appropriate to the scope. Respect audit-only requests; invocation does not authorize unrelated edits or destructive operations.
2. Choose the smallest coherent simplification. Prefer deletion, reuse, or consolidation over replacing one abstraction with another.
3. For code, remove one mechanism at a time and compare the same behavior checks and relevant measurements. Keep supported simplifications; revert unsuccessful experiments without disturbing the user's changes.
4. Preserve safety, authorization, ownership, compatibility, and failure-handling requirements. Do not weaken tests to make an experiment pass. A passing test does not prove an untested contract is dispensable.
5. Validate meaning for prose and observable behavior for code. Where code measurements are supported and relevant, compare the same scope, tool version, and settings before and after. Inspect the diff for costs those metrics miss.
6. Report substantive changes, evidence, and material tradeoffs or uncertainty. Stop when the requested simplification and its proof are complete, not when every metric or stylistic preference is optimized.

The prose reference preserves the body of Cursor's `pstack/skills/unslop/SKILL.md` at the revision recorded above. Lizard measures code complexity and size, not prose quality, redundancy-based verbosity, or structural erosion.
