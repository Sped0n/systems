# ESP-IDF

Apply these platform constraints alongside the shared embedded guidance. For integrated Matter protocol work, also read [Matter and CHIP](MATTER.md).

## FreeRTOS execution

- Choose queues for payload handoff and task notifications for suitable signaling. Define payload ownership and cleanup on successful delivery, queue-full failure, cancellation, and shutdown.
- FreeRTOS queues copy bytes, not C++ object semantics. Do not enqueue non-trivial owner objects by value; queueing a pointer also does not extend its pointee's lifetime.
- Use task mutexes only for unavoidable shared invariants, not as a substitute for state ownership. Recursive mutexes should not conceal unclear call ownership.
- Keep ISRs and critical sections short and non-blocking. Use the appropriate ISR-safe APIs; an ISR cannot take a task mutex. Disabling interrupts on one core does not protect shared state from another core.
- `volatile` is not synchronization. Use atomics only with established memory ordering, target support, and execution-context safety.

## Memory and errors

- Check stack-size and stack-measurement units in the installed ESP-IDF APIs rather than assuming upstream FreeRTOS conventions. Consider the full callback/serialization call chain before increasing a task's stack.
- Select memory by access requirements, not just available capacity. Verify PSRAM configuration, DMA capability/alignment, cache-disabled access, and latency constraints before placing buffers or state in external RAM; handle capability-specific allocation failure.
- Follow ESP-IDF error conventions: prefer `ESP_RETURN_ON_FALSE` for guards and `ESP_RETURN_ON_ERROR` for propagation. Use `ESP_GOTO_ON_*` when C resources need shared cleanup; preserve RAII in C++.
- Handle recoverable failures normally rather than aborting. Log where useful context is available and avoid noisy polling/interrupt-path logging.

## Build and device workflow

- Use the project's matching IDF environment and app root. Consult installed tooling and project configuration rather than carrying version-specific setup workarounds into code.
- Keep component dependencies explicit and independent of configuration values unavailable during component graph expansion. Let dependency manifests and component build definitions own their respective inputs.
- Keep durable settings in project/target defaults. Before regenerating configuration, preserve local settings not represented there and verify the active target's resulting values.
- Regenerate build state through IDF tooling after source/configuration changes; do not repair generated output manually. Run project-level IDF actions sequentially when they share dependency or generated state, even if build directories differ. Report unexpected dependency-lock changes.
- Build the smallest affected target. For resource-sensitive changes, inspect size/map output; for device failures, inspect reset reason, panic/watchdog logs, task stack headroom, and heap behavior before adjusting limits.
- Use the `tmux` skill for monitors and other long-running sessions. Apply the entry document's hardware authorization rules and report any hardware-validation gap.
