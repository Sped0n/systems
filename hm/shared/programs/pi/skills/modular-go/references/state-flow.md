---
urls:
  - https://go.dev/blog/context
  - https://go.dev/doc/effective_go#concurrency
---

# State Flow

Make mutable state ownership, synchronization, and lifecycle explicit.

- Prefer stateless functions for transformations and validation. Pass dependencies and data explicitly instead of using global mutable state.
- Model legitimate transitions according to the domain. One-shot operations benefit from init → advance → finalize; reusable resources may legitimately reconnect, retry, or return to an earlier phase. Prevent invalid transitions rather than forbidding cycles universally.
- Use a lifecycle owner for collections that need coordinated acquisition, mutation, and release. Expose stable IDs when identity is the contract; expose typed handles or values when those make ownership clearer.
- Protect shared invariants with synchronization and narrow lock scope. Do not call blocking or reentrant collaborators while holding a lock unless its contract requires and supports that ordering.
- Pair acquisition with deterministic release on success, failure, cancellation, and shutdown. Coordinate goroutine termination so teardown cannot race with late work.
- Use `context.Context` for cancellation of operations. Provide `Close` or another explicit shutdown operation for owned resources when callers must release them; cancellation alone does not close a resource.
- Translate errors into transport status at request boundaries. Preserve domain error meaning internally.

## Review

Can this behavior be stateless? If not, who owns mutations and valid transitions? What synchronizes shared state? How do cancellation and explicit cleanup interact, and can shutdown wait for all owned work to stop?
