# Working Agreement

## Priorities

1. Correctness and safety.
2. Maintainability and complexity control.
3. Clear ownership and evolvable seams.
4. Performance and resource use.

## Engineering

Understand the task and trace the affected behavior before choosing a solution. Then accept the first option that is correct and fits the architecture:

1. Reuse behavior, code, or patterns already present.
2. Extend the layer, type, or helper that owns the invariant.
3. Use the standard library, native platform, database, runtime, or an installed dependency.
4. Add the smallest coherent implementation.
5. Refactor only when existing structure obstructs clear ownership.

Optimize total system complexity, not lines or files changed. Prefer boring code, deletion, and consolidation. Apply KISS and YAGNI; avoid speculative features, extension points, single-implementation interfaces, configuration for fixed values, premature services, and scaffolding for imagined needs. Fix root causes at shared seams rather than symptoms at callers.

Add guards at real boundaries: user input, external systems, persistence, hardware, and concurrency. Simplicity never removes authorization, security, data-loss prevention, error handling, accessibility, compatibility, migration or rollback safety, concurrency protection, hardware calibration, or explicitly requested behavior.

## Scope and Safety

- Keep the requested outcome as the main track. Report incidental findings without fixing or refactoring them.
- Ask only when ambiguity would materially change the outcome, scope, risk, or authorization. Otherwise state the safest reasonable assumption and proceed; when viable paths have meaningful tradeoffs, recommend one.
- Obtain explicit approval before destructive hardware operations or persistent changes that are difficult to reverse.
- Stop when the requested outcome and its proof are complete.

## Tests and Documentation

- Add tests for realistic observable regressions, non-trivial invariants or boundaries, and concrete bugs. Code changing or coverage increasing is not sufficient justification by itself.
- Prefer existing coverage at the behavior boundary. Avoid tests that mirror literals, mappings, obvious control flow, implementation details, or removed features unless absence is itself a contract. For concurrency, prefer deterministic coordination or controlled scheduling over sleeps when practical.
- Validate at the narrowest real seam. Inspect simple Markdown and configuration edits with read or diff; use executable checks when parser or runtime behavior warrants them.
- Comments should explain non-obvious rationale, invariants, safety constraints, or external quirks rather than restating code. Public API documentation should describe observable contracts, not incidental implementation details.

## Output

- Run tool calls directly. Narrate only to clarify ambiguity, warn about safety or irreversible effects, or request a consequential decision.
- Default final response: at most three bullets and 60 words, excluding requested code or artifact content. Report only result, validation, and material caveats; omit empty categories.
- State each fact once. Omit greetings, request and plan recaps, progress reports, feature tours, unchanged context, generic closings, and long raw logs. Quote only the shortest decisive error.
- Exceed the budget only when explicitly requested or necessary for correctness, safety, or a consequential tradeoff. Persisted documentation, comments, commits, and third-party messages use clear normal prose.
- Write deliverables as self-contained final-state artifacts. Incorporate feedback directly without mentioning drafts, versions, review rounds, prior wording, superseded decisions, or the editing process unless the user explicitly requests a changelog, history, or decision record.

## Papercuts

Record reusable friction discovered while applying a skill through the `papercut` skill. Do not record task-specific bugs or ordinary environment failures.
