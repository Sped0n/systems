---
name: coding-style
description: Write and review code with precise names, deliberate function boundaries, the rule of three, direct control flow, and useful comments. Apply across languages while preserving repository conventions.
metadata:
  style_references: |
    https://github.com/vczh-libraries/Release/blob/48b0031384dfafc04f3b30d58dea3d546e7607a1/.github/Guidelines/Coding.md
    https://github.com/tigerbeetle/tigerbeetle/blob/3a43dce1cdba4ce132ac6194cf852262247aa861/docs/TIGER_STYLE.md
  adaptation: "Local conventions combining selected vczh and Tiger Style principles with the rule of three."
---

# Coding style

Make the code's meaning discoverable, its behavior locally understandable, and its abstractions justify their existence. These rules govern how code is expressed, not which architecture or language features a project must use. Follow established repository conventions and preserve compatibility unless a breaking change is authorized.

## Use precise, searchable names

- Search existing vocabulary before introducing a name. Use one canonical spelling per concept across code, configuration, diagnostics, and documentation. Do not give one domain term several unrelated meanings.
- Name entities with concrete nouns and operations with precise verbs. Name files after the responsibility they own. Avoid vague names such as `utils`, `helpers`, or `manager` when a specific responsibility can be named.
- Prefer full words, with established domain acronyms where appropriate. Follow the language's casing conventions. Prefer supported long-form flags in scripts; short flags are suitable for interactive use.
- Put the concept before units and qualifiers where repository conventions permit: `timeout_ms_max`, not `max_timeout_ms`. Preserve established public names.
- Use parallel names for parallel roles: `source_offset` and `target_offset`. Do not distort meaning to make names the same length.
- Distinguish indexes, counts, and byte sizes. Make consequential units, rounding, and inclusive or exclusive bounds apparent through names, types, or the contract.
- Design public names from the caller's vocabulary. Use named arguments or an options value when same-typed positional arguments are easy to swap. Do not introduce a builder solely to name arguments.
- Keep stable event names, flags, error codes, and diagnostic prefixes as complete searchable literals where practical. Keep runtime values separate and preserve localization conventions.

## Extract knowledge, not repeated syntax

Reuse existing behavior before writing another implementation. Share domain knowledge and behavior that must remain consistent, not every similar sequence of statements.

Apply the rule of three to emerging reuse:

1. Implement the first occurrence directly.
2. At the second occurrence, tolerate duplication while determining whether the responsibility is genuinely shared.
3. At the third occurrence of the same meaningful logic, extract the shared responsibility and consolidate its callers.

Do not wait for three copies of a correctness-critical rule. Protocol encodings, authorization decisions, and other authoritative knowledge need one owner from the start. Conversely, similar syntax is not proof of a shared responsibility. If an extraction requires caller-specific branches or mode flags, reconsider whether those operations belong together.

Give each abstraction a concrete benefit: a shared rule, a meaningful operation, a resource boundary, or a complex calculation. A single-use helper is appropriate for one of these purposes. It is not justified merely because it makes its caller shorter or hides a few obvious assignments.

Avoid wrappers that only rename an SDK or library call. Add one when it establishes a real contract, not to anticipate hypothetical implementations. Do not introduce generators, interfaces, or configuration merely to avoid a small amount of straightforward code.

## Keep control flow locally understandable

- Keep the normal path easy to follow. Use guard clauses when they reduce nesting without hiding cleanup or changing failure behavior.
- Keep variables narrowly scoped and calculations near their use. Avoid aliases that merely rename obvious expressions or create another value to keep synchronized.
- Name a complicated condition when the name expresses domain meaning. Split compound conditions when doing so clarifies their cases, not as a mechanical rewrite of every boolean expression.
- Keep orchestration readable without hiding each step behind a helper. A reader should be able to locate consequential effects and error paths without tracing a chain of trivial functions.
- Use the simplest signature that expresses the full contract. Do not discard meaningful failure information to make a signature smaller.
- Express programmer invariants through types or appropriate assertions. Handle invalid external input and expected operating failures through normal error paths. Follow the project's failure policy; add neither redundant validation nor assertions to meet a quota.
- Keep functions cohesive and understandable as a whole. Neither a fixed line limit nor a desire for fewer functions justifies a poor boundary.

## Make layout and comments useful

- Order definitions for a coherent first read where the language permits it. Group related operations and keep a concept's contract near its definition.
- Preserve the relationship between dedicated helpers and their operation when naming would otherwise hide it: `read_sector` and `read_sector_callback`. Do not give a shared helper a misleading single-caller name.
- Separate logical steps with blank lines, not every statement. Follow the repository's formatter; do not introduce alignment churn or unrelated formatting changes.
- Document rationale, constraints, surprising behavior, and contracts that names and types cannot express. Do not narrate statements or repeat names.
- Explain why a non-obvious operation is valid at the relevant definition or boundary. State ownership, ordering, or lifetime requirements there rather than leaving callers to reconstruct them.

## Boundaries and review

Use the other skills when the task crosses these boundaries:

- For domain models and data structures, read [Modeling](../principle-modeling/SKILL.md).
- For transitions, shared mutation, retries, and recovery, read [State management](../principle-state-management/SKILL.md).
- For removal experiments and complexity measurements, read [Simplification](../principle-simplify/SKILL.md).
- For test design, read [Behavior tests](../principle-test-behavior-not-implementation/SKILL.md).
- For explanatory prose, read [Technical writing](../technical-writing/SKILL.md). This skill decides what code comments must explain, not the prose-editing workflow.
- For embedded C/C++ feature choices, preprocessor conventions, and SDK constraints, read [Espressif](../espressif/SKILL.md).

For a rename or move, search affected callers, configuration, diagnostics, tests, and documentation. Preserve externally consumed names, persisted keys, and intentional aliases unless their migration is authorized. Check that a search for the domain concept finds its authoritative implementation and contract. Do not turn a focused style change into unrelated architectural work.
