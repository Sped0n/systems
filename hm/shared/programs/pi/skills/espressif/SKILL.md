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

## Embedded C++ subset

Apply this conservative subset to application code; preserve vendor/generated SDK conventions and required interfaces rather than rewriting them into C.

- Prefer explicit types, functions, structs, scoped enums, `constexpr` constants, and straightforward control flow. Use small classes only when they own resources or enforce a real invariant.
- Allow deterministic RAII, `std::unique_ptr`, references, const correctness, and simple value types. Make copying intentional and match allocation/release APIs; destructors must run in a valid cleanup context. Inspect SDK wrappers rather than assuming standard ownership or move semantics.
- Use bounded containers and established SDK types when their cost and failure contract fit. Avoid unbounded growth and implicit allocation in latency-sensitive paths. Spell consequential types explicitly; reserve `auto` for cases where the type is locally obvious or unwieldy SDK iterator syntax would obscure the operation.
- Keep lambdas short with explicit captures and a visible lifetime. Do not use capture-all callbacks for queued or asynchronous work.
- Keep deep inheritance, custom template frameworks/metaprogramming, overloaded operators, shared ownership, and type-erased callbacks outside the default subset. An exception needs a concrete SDK requirement or measurable benefit, with allocation, dispatch, and lifetime costs explained.
- Do not introduce exceptions or RTTI into a build that disables them. Follow the project's configured error conventions and inspect the target/toolchain before relying on a library feature.

## Macros, namespaces, and local readability

- Prefer a function, `constexpr`, or scoped enum over a new application macro when it can express the same contract. Preserve SDK macros that implement logging, configuration, error propagation, or placement requirements.
- Document non-obvious macro behavior near its definition or first consequential use: repeated argument evaluation, hidden return/goto, cleanup requirements, context restrictions, or target placement. Do not add comments that merely expand obvious names.
- Keep namespace nesting shallow and avoid `using namespace` in headers. Close nontrivial namespace blocks with `}  // namespace name`, including `}  // namespace` for an anonymous namespace. Explain a namespace's responsibility only when its name and contents do not make it evident.
- Keep preprocessor branches readable; label distant or nested `#endif` lines with the relevant condition. Comments should expose rationale and hidden control flow, not narrate each statement.

## SDK guidance and validation

- For ESP-IDF/FreeRTOS execution, memory placement, component configuration, build, or hardware work, read [ESP-IDF](ESP-IDF.md).
- For Matter/CHIP/esp_matter controllers, discovery, subscriptions, clusters, or protocol callbacks, read [Matter and CHIP](MATTER.md), including non-ESP Matter work. Read both references for integration across the stacks.
- Keep application policy outside vendor, managed, and generated code; do not edit those files unless explicitly requested. Preserve local configuration when regenerating build inputs.
- Flash only when requested or clearly required. Obtain explicit approval before destructive hardware operations or persistent changes that are difficult to reverse.
- Validate the smallest affected target and realistic failure/lifecycle boundaries. Report untested hardware or resource assumptions.
