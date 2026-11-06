---
name: principle-state-management
description: "Apply when designing lifecycle states, concurrent writers, validation boundaries, or operations that run amid crashes, restarts, and retries. Make ownership and transitions explicit, eliminate unnecessary sharing, and converge after partial runs."
disable-model-invocation: true
metadata:
  source: "https://github.com/cursor/plugins"
  commit: "2776ddd2355d6d6c8747d3964600f28daf62f049"
  adaptation: "Combines principle-separate-before-serializing-shared-state, principle-make-operations-idempotent, and principle-boundary-discipline with explicit state-machine guidance."
---

# State Management

## Model Lifecycle States and Transitions

Prefer a state machine with a state enum or discriminated union over scattered booleans, phase strings, and lifecycle checks. Represent mutually exclusive states once. Attach state-specific data to the corresponding variant where the language permits it.

**Why:** Separate flags can represent combinations the lifecycle should never allow. A state enum names the valid states; a transition function makes the rules for moving between them explicit.

**The pattern:**
- Name the valid states, events, and transitions, including failure, cancellation, and recovery where required.
- Give one owner responsibility for applying transitions. Define what happens when an event is invalid, duplicated, or arrives late.
- Derive flags such as `isReady` from the authoritative state rather than storing copies that must stay synchronized.
- Keep independent dimensions separate. Do not force unrelated facts into one giant enum or introduce a state-machine framework when an enum and a transition function suffice.
- Separate transition decisions from effects where practical. An enum does not make concurrent transitions atomic or external effects safe to repeat.

Verify legal and rejected transitions through the real interfaces. Include the events and failure paths the operation must handle, not just the successful sequence.

## Separate Before Serializing Shared State

When concurrent actors might share mutable state, first ask whether they need the same mutable object. If not, eliminate the sharing. When sharing is real, enforce serialization structurally: lockfiles, sequential phases, exclusive ownership. Instructions and conventions are not concurrency control.

**Why:** Concurrent writes to shared state create race conditions that are intermittent, hard to reproduce, and expensive to debug.

**Pattern:**
1. **Identify shared mutable state** (files both read and write, branches both push to, APIs both define and consume).
2. **Default: eliminate the shared write target.** Ask: do these actors need one canonical object, or are they publishing independent facts? Give each actor its own owned file, key, branch, or state directory, and merge only at the read/reporting boundary. Two workers writing their own `lastX` field into one `state.json` is still shared mutation. `indexer-state.json` + `metrics-state.json` is not, provided there is no cross-file atomicity requirement.
3. **Only when one shared write target is a real invariant, serialize access structurally** (lockfiles, transactions, sequential phases, single-writer actor, or atomic compare-and-swap). Protect the entire read-modify-write operation. Treat "we need a lock" as a design smell to check, not as the default answer.

## Make Operations Idempotent

Design operations so they converge to the correct state regardless of how many times they run or where the previous run stopped. Every state-mutating operation should answer: "What happens if this runs twice? What happens if the previous run crashed halfway?"

**Why:** Commands, lifecycle operations, and processing loops run where crashes, restarts, and retries are normal. If partial state changes the next run's outcome, every restart becomes a debugging session.

**The idea:** derive each step from the state that exists, not from what the previous run meant to do. Read the current state, compare it to the goal, and apply only the difference. A step written this way is safe to repeat, because a repeat finds nothing left to do.

Anything a run leaves behind, such as a lock, a temporary file, a half-written record, or a claimed job, must be recognizable as active, stale, or incomplete by the next run. Judge staleness by evidence that stays true wherever the previous run could have stopped, not only in the common case. Elapsed time alone does not prove an owner is dead. A marker that the next run cannot judge turns every crash into manual cleanup. For example, write to a temporary path and rename it into place, or compare artifacts by content instead of by creation order.

Use atomic rename where supported for file publication. Atomic publication does not by itself provide crash durability or prevent concurrent lost updates.

For effects that cannot simply be repeated, such as payments or messages, use the external system's idempotency contract, durable deduplication, or a reconciliation protocol. A local completion flag cannot close the gap between an external effect and a crash before recording it.

**The test:**
1. What happens if this runs twice in a row?
2. What happens if the previous run crashed at every possible point, including after an effect but before acknowledgment?
3. Does re-execution converge to the same end state without duplicate effects?

If any answer is "it depends on what state was left behind," the operation needs a reconciliation step. Check repeat execution and meaningful interruption points through the real interfaces, including concurrent ownership and observable effects.

## Boundary Discipline

Place validation, type narrowing, and error handling at system boundaries. Inside the validated domain, trust established type and ownership guarantees. Business logic lives in pure functions where practical. The shell is thin and mechanical.

**Why:** Scattered validation is noisy, redundant, and gives a false sense of safety. Keep logic out of framework wiring so it can be tested without the framework.

**The pattern:**
- **At boundaries** (CLI args, config files, external APIs, network protocols, persistence, hardware): validate, return errors, handle defensively.
- **Inside the system:** typed data, error propagation, no redundant re-validation. Trust the types while their guarantees hold. Do not swallow failures.
- **Across the boundary.** Expose domain concepts, not the boundary's private representation. Keep general-purpose mechanism inside and special-purpose policy at the edge.

Retain guards where established guarantees can change, especially authorization, concurrency, and hardware constraints. An earlier validation does not make mutable state permanently valid.

**Applications:**

Validation and error handling:
- Validate config at parse time (the boundary), not inside business logic
- Parse raw data into domain types at the boundary
- Do not re-export transport, storage, framework, or wire types through the public surface
- No redundant nil checks deep in call chains if the boundary already validated

Code organization:
- Business logic in pure functions with no framework dependencies
- Parse functions: pure transforms from raw bytes to typed state
- Prompt construction: structured state in, string out
- Scoring and assessment: pure transforms from state to results
- Transition decisions: typed state and event in, next state and required effects out

The adapter reads inputs, invokes these functions, applies effects, and reports errors. Keep framework wiring out of the decision logic.

**The tests:**
- "Is this data crossing a system boundary right now?" If not, and the established guarantees still hold, validation is redundant.
- "Can this be a pure function that the shell just calls?" If yes, extract it.
