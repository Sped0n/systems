---
name: principle-modeling
description: "Apply before writing logic: choosing core types and data structures, sequencing shared foundations and features, or finding repeated shape assumptions and branches across files. Get the data structures right so downstream code becomes obvious."
disable-model-invocation: true
metadata:
  source: "https://github.com/cursor/plugins"
  commit: "2776ddd2355d6d6c8747d3964600f28daf62f049"
  adaptation: "Combines principle-foundational-thinking and principle-model-the-domain; lifecycle and concurrency details live in principle-state-management."
---

# Modeling

## Foundational Thinking

**Structural decisions** protect option value. **Code-level decisions** protect simplicity.

**Data structures first.** Get the data shape right before writing logic. Define core types early, trace every access pattern, and choose structures that match the dominant paths.

At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

**Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate unless one shared mutable object is a real invariant. For ownership and coordination, read [State management](../principle-state-management/SKILL.md).

**Scaffold first.** If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, relevant tests before fixes. Keep commits small and single-purpose. Add infrastructure for the planned work, not hypothetical phases.

Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

Subtraction comes before scaffolding. Trace actual use and remove dead code that obstructs the requested change first, then lay foundations.

## Model the Domain

Encode the real domain in a data structure instead of scattering it across conditionals. A structure that matches the domain makes invalid states unrepresentable and deletes branches. Choosing it at write time is cheap. Recovering it later reads as a refactor and gets deferred.

Reach for:

- A state machine instead of scattered booleans, phases, or lifecycle checks. For state enums, transitions, retries, and concurrent writers, read [State management](../principle-state-management/SKILL.md).
- A typed model instead of loose parameters or repeated shape assumptions.
- A map, registry, lookup table, or discriminated union instead of branching spread across files.
- A reducer or command/event model instead of ad hoc state mutations.
- A module organized around one body of domain knowledge instead of a sequence such as load, validate, transform, and save. Execution order is not ownership.
- A small module boundary that gathers repeated behavior, ownership, or invariants.
- A queue, cache, index, graph, tree, or normalized collection where the access pattern calls for it.
- Any other structure that fits. When none fits, work out what the code must never allow and how the data gets read, then find the structure that encodes exactly that.

### Check functional independence with Axiomatic Design

Use the Independence Axiom of Axiomatic Design to ask: when one behavior needs to change, which other behaviors must be adjusted to compensate? For example, changing a report's display precision should not change its calculated totals. If it does, presentation and calculation share a decision that should be independent.

When the interactions are hard to reason about, build a design matrix. Put functional requirements (the outcomes required) in rows and design parameters (the decisions you can adjust) in columns. Mark a cell when changing that parameter can affect that requirement. Ground each mark in a contract, code path, or observed behavior, not merely an import.

- A **diagonal matrix** represents an *uncoupled* design: each parameter affects only its corresponding requirement.
- A **triangular matrix** represents a *decoupled* design when it has off-diagonal dependencies: the requirements can be satisfied by setting the parameters in order, without undoing earlier work. Lower versus upper depends on the ordering.
- If no ordering makes the matrix triangular, identify the specific decisions that require mutual adjustment. Recommend a different boundary when that coupling obstructs a required change, not merely to make the matrix look cleaner.

Do not force an abstraction. Prefer boring code if the current shape is already clear, local, and unlikely to grow. Be skeptical of an abstraction that adds indirection without removing branches, duplicated rules, invalid states, or lifecycle risk.

The sign that you skipped this is a new feature that grows an existing if/else chain by one more branch, or a second boolean that must stay in sync with the first. Temporal decomposition is another sign. Phase-named modules repeat the same domain rules across steps. These are reasons to inspect the model, not automatic permission for an unrelated refactor.
