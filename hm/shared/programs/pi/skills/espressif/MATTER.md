# Matter and CHIP

Apply these protocol constraints alongside the shared embedded guidance. For ESP-IDF integration, build, or hardware work, also read [ESP-IDF](ESP-IDF.md).

## SDK and protocol boundaries

- Inspect the active checkout's agent guidance, API contracts, and nearby implementations. Consult its cluster/application documentation for implementation-specific methods, build registration, and testing conventions rather than transferring recipes between SDK versions.
- Follow upstream CHIP idioms within CHIP modules. Prefer established protocol value types, spans, bounded storage, and platform allocators over parallel abstractions; borrowed views do not own their backing storage.
- Keep protocol logic separate from application policy and generated configuration. For code-driven clusters, confine legacy/generated accessors to the integration layer and use the capabilities supplied by the framework.
- Treat the applicable specification revision as the source of protocol requirements. Do not infer compliance from examples or memory; state uncertainty when the relevant specification is unavailable.

## Lifecycle and threading

- Keep controller requests, discovery, retries, and subscriptions under one protocol owner. Capability-specific handlers should not launch independent global lifecycle loops.
- Separate authoritative device identity from transient reachability/discovery. A failed refresh is not evidence that a known device should be removed; preserve usable prior state when safe.
- Access CHIP state through its required event-loop or stack-lock contract. Avoid layering per-object mutexes over existing serialization, and never wait for work while holding a lock that work needs.
- Distinguish initialization/shutdown phases from normal runtime synchronization. Verify what lock-state and readiness queries actually guarantee in the active platform implementation.
- Keep callback contexts and subscription owners alive through their SDK-defined completion/cancellation boundary. Copy decoded data that must outlive a callback, and cancel timers/registrations before releasing their owner.

## Errors and data-model behavior

- Use `CHIP_ERROR` where the API requires it, `VerifyOrReturnError` for guards, and `ReturnErrorOnFailure` for propagation. Preserve Interaction Model status types at protocol interfaces rather than flattening them into platform errors.
- Prefer RAII cleanup; use `VerifyOrExit` for a genuine shared cleanup path. Reserve `VerifyOrDie` for programmer invariants, not malformed remote input or recoverable runtime failures.
- Ignore invalid callbacks only when the lifecycle contract permits it. Handle or intentionally log fire-and-forget failures with categorized `ChipLog*` logging; a successful callback missing required data is still a boundary error.
- Rely on established framework dispatch guarantees instead of duplicating path checks, but still validate decoded values and runtime constraints. Keep advertised capabilities consistent with implemented behavior.
- Give response encoding and attribute-change notification one owner. Use framework mutation/response contracts so updates notify subscribers correctly and a command does not emit duplicate responses.

## Validation

- Build and test the smallest affected SDK target using its documented environment. Use an ESP-IDF build for ESP integration changes, not as a universal requirement for upstream Matter work.
- Cover changed protocol boundaries such as invalid/nullable values, optional capabilities, response behavior, and subscription teardown. Prefer existing test contexts and controlled clocks over global singleton fixtures and sleeps.
- Measure RAM/flash-sensitive changes on equivalent embedded targets; host success alone does not prove device suitability. Preserve public API compatibility or document an explicitly authorized migration.
