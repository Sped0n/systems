---
name: simplify
description: Use first-principles reasoning and reversible ablation experiments to remove unnecessary code mechanisms while preserving required behavior.
disable-model-invocation: true
---

# Simplify

Start from the required outcomes, inputs, constraints, and failure behavior rather than the existing architecture. Separate actual requirements from assumptions about how they must be implemented. Identify mechanisms whose removal could make the whole system simpler, not merely move complexity elsewhere.

Establish behavior checks and relevant baseline measurements. Remove one mechanism at a time and compare the same checks and measurements. Keep supported simplifications; revert unsuccessful experiments without disturbing the user's changes. For complexity and size comparisons, use the [Lizard workflow](../unslop/references/code-evaluation.md).

Do not weaken tests or remove safety, authorization, ownership, or compatibility requirements to make an experiment pass. A passing test does not prove an untested contract is dispensable. Respect audit-only requests; invocation does not authorize unrelated edits or destructive operations.

Report what was removed, the evidence, and any uncertainty. Stop when the requested simplification and its proof are complete.
