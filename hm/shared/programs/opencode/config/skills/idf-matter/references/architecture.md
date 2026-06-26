---
urls:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/build-system.html
  - https://docs.espressif.com/projects/esp-matter/en/latest/esp32/developing.html
---

# ESP-IDF / Matter Architecture

## Goals

- Keep each module responsibility explainable in one sentence.
- Make state ownership obvious.
- Keep protocol, UI, domain state, and hardware/platform code from leaking into each other.
- Preserve app-specific hardware behavior outside dependency/vendor code unless explicitly asked.

## Boundary Pattern

- Orchestration: lifecycle, work queues, callbacks, retries, timers, and cross-module state machines.
- Domain/model: app-owned state, registries, catalogs, caches, identity, and type mapping.
- Protocol adapters: Matter reads/writes/subscriptions, RainMaker/cloud fetches, BLE/Wi-Fi/provisioning, and error translation.
- Capability handlers: concrete device behavior or feature-specific commands/reports; no global lifecycle ownership.
- UI adapter/view-model: UI-facing snapshots, enum states, labels, affordances, and debounced user intents.
- UI rendering: LVGL/widgets/screens/events only; no protocol decisions.
- Platform/hardware: board peripherals, power, sensors, buses, calibration, and shutdown policy.
- Components: reusable local components with clear owner; dependency code stays dependency code.
- Managed/generated code: do not edit unless the user explicitly asks.

## General Rules

- Centralize state mutation in the owner; expose snapshots or narrow queries to consumers.
- Keep async API request, callback completion, retry, and failure state in one lifecycle owner.
- Separate catalog/identity source from live protocol discovery when both exist.
- Put subscriptions under controller/protocol orchestration, not under one device capability.
- Keep UI busy/error/empty states derived from one enum where possible.
- Keep hardware policy near platform/power owner, not scattered through UI or protocol callbacks.

## Boundary Smells

- UI code includes protocol controller headers directly.
- Capability handler starts global discovery, retry, or subscription loops.
- Multiple modules track the same `fetching`, `discovering`, `subscribing`, or `failed` state.
- Domain/model code drives LVGL updates.
- Hardware GPIO/bus policy is hidden inside unrelated device UI code.
- A new helper or wrapper is used once and only hides one or two lines.
- A file move creates forwarding headers or compatibility shims without persisted data or external users requiring them.

## Refactor Direction

- Move state mutation toward the existing owner before adding a new owner.
- Prefer renaming/moving a misplaced module over adding forwarding wrappers.
- If two modules need same data, expose a snapshot/query from the owner; do not duplicate state.
- If a module cannot be described in one sentence, split by responsibility seam, not line count.
