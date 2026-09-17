---
name: espressif
description: Practical guidance for writing, reviewing, and debugging ESP-IDF and Matter/CHIP embedded code, including state ownership, concurrency, resource budgets, and readable C-style C++.
---

# Espressif

Build predictable embedded software with clear state ownership and visible execution and resource costs. General naming and searchability belong to `write-discoverable-code`; this skill adds embedded and SDK constraints.

## State and lifecycle

- Represent mutually exclusive phases with a small enum and explicit transitions rather than scattered flags. Keep genuinely independent facts separate instead of constructing a combinatorial state machine.
- Give each lifecycle one mutation owner. Keep requests, callbacks, timers, retries, and shutdown under that owner; expose operations and snapshots rather than writable internals.
- Establish pending state before submitting work that may complete synchronously. Distinguish submission failure, request acceptance, and actual completion.
- Design cancellation and teardown alongside startup. Queued work and late callbacks must not access destroyed state or complete a newer operation.

## Concurrency and timing

- Prefer serialization in an existing task or event loop over adding tasks and mutexes. Reduce shared mutation through interface design; an interface alone does not synchronize cross-task access.
- When sharing is necessary, protect the invariant rather than individual fields. Keep lock ownership and order clear; do not hold locks across blocking work or callbacks that may re-enter the owner.
- Bound work in interrupts and latency-sensitive callbacks, then defer the remainder. Account for queue saturation, backpressure, and worst-case execution time rather than relying on delays or larger watchdog timeouts.

## Resource budgets

- Budget stack, heap, static RAM, and flash together. Large locals threaten task stacks; static storage consumes permanent RAM and changes reentrancy; heap allocation adds failure and fragmentation risks.
- Prefer bounded in-place storage or existing pools for predictable hot paths. Allocate when size or lifetime warrants it, handle failure, and avoid repeated growth and copying.
- Account for task stacks, queue storage, callback payloads, and shutdown cleanup when adding asynchronous work. Borrowed data must remain valid until its last use.
- Preserve numeric precision, lengths, and null/empty distinctions at serialization boundaries. Check the target representation rather than assuming host behavior.
- Measure resource-sensitive changes on equivalent target builds. Use map/size reports, stack headroom, and heap behavior under representative load; successful compilation does not establish runtime headroom.

## Embedded C++

- Prefer straightforward functions, structs, enums, and explicit control flow in application code. Preserve local C-style conventions without rewriting upstream SDK idioms into C.
- Use RAII, `std::unique_ptr`, const correctness, and simple value types when they make ownership and invariants safer. Control copying and match allocation/release APIs; cleanup must occur in the required execution context.
- Avoid deep inheritance, elaborate templates, shared ownership, and type-erased callbacks without a concrete benefit. Make consequential types, captures, allocation, and lifetime costs apparent without requiring an LSP.
- Choose features by clarity and cost, not by language age. Do not assume an SDK resource wrapper has standard-library ownership or move semantics; inspect its contract before changing replacement or cleanup.

## SDK guidance and validation

- For ESP-IDF/FreeRTOS execution, memory placement, component configuration, build, or hardware work, read [ESP-IDF](ESP-IDF.md).
- For Matter/CHIP/esp_matter controllers, discovery, subscriptions, clusters, or protocol callbacks, read [Matter and CHIP](MATTER.md), including non-ESP Matter work. Read both references for integration across the stacks.
- Keep application policy outside vendor, managed, and generated code; do not edit those files unless explicitly requested. Preserve local configuration when regenerating build inputs.
- Flash only when requested or clearly required. Obtain explicit approval before destructive hardware operations or persistent changes that are difficult to reverse.
- Validate the smallest affected target and realistic failure/lifecycle boundaries. Report untested hardware or resource assumptions.
