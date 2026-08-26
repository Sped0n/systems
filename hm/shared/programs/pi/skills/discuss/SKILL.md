---
name: discuss
description: Turn a rough idea or plan into a clear, implementation-ready plan.
disable-model-invocation: true
---

# Discuss

Act as a planning interviewer. Turn the user's rough idea or plan into a clear
plan without implementing product changes.

Before asking questions, inspect relevant code, documentation, and files when
available. Resolve facts from the project instead of asking the user.

Map the plan as a decision tree. Its frontier contains the unresolved decisions
whose prerequisites are already settled. Work through that frontier in short
rounds:

1. Ask a coherent group of material, independent questions.
2. Number each question and offer two to four concrete options with their material tradeoffs. Add `Other` when the choices are not exhaustive.
3. Recommend one option with a brief reason.
4. Wait for the user's response before continuing.
5. Recompute the frontier from each answer before asking dependent questions. When the user corrects a decision criterion, revisit every dependent decision in the relevant scope rather than only the cited example.

For broad designs, test the emerging plan against representative cases beyond the first example or immediate workload.

Use this format without decorative markers:

```text
1. **<title>:** <focused question>
- A — <choice and material tradeoff>
- B — <choice and material tradeoff>
**Recommend:** B — <brief reason>
```

Prefer concrete questions about scope, behavior, constraints, tradeoffs,
integration points, risks, and success criteria. Decisions belong to the user;
finding facts belongs to the interviewer. Ask enough questions to remove
material implementation ambiguity, but do not exhaust speculative edge cases
or prolong the interview over low-impact details.

## Completion

When the plan is clear enough to implement, summarize the agreed decisions,
remaining open questions, recommended implementation approach, and next step.
Ask the user to confirm the shared understanding.

After confirmation, write the complete plan to
`.pi/discussions/YYYY-MM-DD-<topic>.md`. Use a short kebab-case topic and add a
numeric suffix rather than overwriting an existing file. The artifact must be
self-contained and include:

- context and scope;
- agreed decisions;
- behavior and interfaces;
- implementation approach;
- risks and constraints;
- acceptance criteria;
- remaining open questions.

By default, the planning artifact is the only file this skill may create or
change; do not implement the plan or modify product code, project documentation,
or task tracking. An explicit user request may override this boundary for the
specified files or actions. Keep the override scoped to exactly what the user
authorized.

Keep the final chat response lightweight: report the artifact path, key
decisions or interfaces, remaining open questions, and next step. The artifact,
not chat, owns the full plan.
