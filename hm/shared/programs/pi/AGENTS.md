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

- Inspect existing coverage before adding tests. Add or extend a behavior test only for a concrete regression, non-trivial invariant, or boundary that existing checks would miss. Changed code and increased coverage are not sufficient justification.
- Test observable behavior at the real contract boundary. Do not mock away the contract being verified or duplicate implementation assumptions in the harness. Avoid tests that merely restate literals, mappings, obvious control flow, or internal call counts.
- Delete tests made obsolete by removed features. Do not add tombstone tests that only assert deleted symbols, options, or mechanisms remain absent. Retain rejection tests when rejection is a maintained compatibility or safety contract.
- Match verification to scope and risk. Prefer diff inspection for prose and parser/schema checks for declarative configuration. Run relevant tests and required project checks; broaden or repeat verification only for new changes, failures, or unresolved concerns. Stop when the requested behavior is demonstrated and required checks pass.
- Keep documentation concise and limited to relevant behavior, configuration, failure modes, and operational constraints. Comments should explain non-obvious rationale, invariants, safety constraints, or external quirks rather than restate code.

## Output

- Run tool calls directly. Narrate only to clarify ambiguity, warn about safety or irreversible effects, or request a consequential decision.
- Default final response: at most three bullets and 60 words, excluding requested code or artifact content. Report only result, validation, and material caveats; omit empty categories.
- State each fact once. Omit greetings, request and plan recaps, progress reports, feature tours, unchanged context, generic closings, and long raw logs. Quote only the shortest decisive error.
- Exceed the budget only when explicitly requested or necessary for correctness, safety, or a consequential tradeoff. Persisted documentation, comments, commits, and third-party messages use clear normal prose.
- Write deliverables as self-contained final-state artifacts. Incorporate feedback directly without mentioning drafts, versions, review rounds, prior wording, superseded decisions, or the editing process unless the user explicitly requests a changelog, history, or decision record.

## Papercuts

Record reusable friction discovered while applying a skill through the `papercut` skill. For audit-only or read-only tasks, defer recording until writes are authorized. Do not record task-specific bugs or ordinary environment failures.
