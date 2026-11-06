---
name: espressif
description: Write, review, and debug ESP-IDF and Matter/CHIP code using an explicit C-style C++ subset, SDK lifecycle contracts, and embedded resource constraints.
---

# Espressif

Build predictable embedded software with visible execution and resource costs. This skill owns the embedded C/C++ dialect and SDK constraints. [Coding style](../coding-style/SKILL.md) owns naming, function boundaries, the rule of three, general control flow, and comment quality.

## Select the relevant guidance

- When writing or reviewing application C or C++, read [C and C++ conventions](CPP.md). Apply the C-compatible rules to C files; do not introduce C++ syntax into them.
- For state machines, mutation ownership, concurrency design, or retry recovery, read [State management](../principle-state-management/SKILL.md). The sections below cover embedded consequences rather than restating that policy.
- For FreeRTOS execution, memory placement, component configuration, builds, or device work, read [ESP-IDF](ESP-IDF.md).
- For Matter/CHIP/esp_matter controllers, discovery, subscriptions, clusters, or protocol callbacks, read [Matter and CHIP](MATTER.md), including non-ESP Matter work. Read both SDK references for integration across the stacks.

## Embedded lifecycle and execution

- Establish pending state before submitting SDK work that may complete synchronously. Distinguish submission failure, acceptance, and completion.
- Keep callback contexts and borrowed payloads valid through the SDK's completion or cancellation boundary. Teardown must account for queued work, timers, and late callbacks, including a callback from an earlier operation arriving during a newer one.
- When mutation must be serialized, reuse the SDK's existing task or event loop where its contract permits. Do not add a task or mutex per object without a concrete need. An interface alone does not synchronize cross-task access.
- Do not hold locks across blocking SDK calls or callbacks that may re-enter the owner. Verify which execution context owns each operation and which contexts can invoke its callbacks.
- Bound work in interrupts and latency-sensitive callbacks, then defer the remainder. Account for queue saturation, backpressure, and worst-case execution time instead of relying on delays or larger watchdog timeouts.

## Resource budgets

- Budget stack, heap, static RAM, and flash together. Large locals threaten task stacks; static storage consumes permanent RAM and affects reentrancy; heap allocation can fail or fragment memory.
- Prefer bounded in-place storage or established pools for predictable hot paths. Allocate when size or lifetime warrants it, handle failure, and avoid repeated growth and copying.
- Include task stacks, queue storage, callback payloads, and shutdown cleanup in the cost of asynchronous work.
- Preserve numeric precision, lengths, and null/empty distinctions at serialization boundaries. Verify the target representation rather than assuming host behavior.

## Scope and verification

Keep application policy outside vendor, managed, and generated code. Do not edit those files unless explicitly requested. Fix generator inputs instead of generated output, and preserve local configuration before regenerating build inputs.

Match verification to the changed contract:

| Change | Relevant evidence |
|---|---|
| SDK integration or component configuration | Build the smallest affected target in the matching SDK environment. |
| Callback, queue, or lifecycle behavior | Exercise submission failure, queue-full handling, cancellation, and late completion where applicable. |
| Allocation, storage, or task sizing | Compare equivalent target builds and inspect map/size reports, stack headroom, and heap behavior under representative load. |
| Matter protocol behavior | Check the affected decoding, response, notification, or subscription contract using the SDK's test facilities. |
| Device failure | Inspect reset reason, panic/watchdog logs, and runtime resource evidence before changing limits. |

Compilation alone does not establish runtime resource headroom, and host tests do not establish hardware behavior. Report any untested hardware or resource assumptions.

Flash only when requested or clearly required. Obtain explicit approval before destructive hardware operations or persistent changes that are difficult to reverse.
