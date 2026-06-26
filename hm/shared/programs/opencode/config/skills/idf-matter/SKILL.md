---
name: idf-matter
description: Practical guidance for ESP-IDF, esp_matter, Matter controller, ESP RainMaker, and embedded UI work. Use when writing, refactoring, reviewing, debugging, building, flashing, or monitoring ESP-IDF/Matter code, especially state machines, UI boundaries, subscriptions, device catalogs, generated files, and CMake component requirements.
---

# idf-matter

Concise guidance for maintainable ESP-IDF and Matter code: small boundaries, centralized state, explicit lifecycles, and idiomatic error handling.

## Purpose and Triggers

- Use for ESP-IDF, esp_matter, Matter, CHIP, ESP RainMaker, FreeRTOS, LVGL, board-manager, power-management, and device-controller work.
- Use for files under `main/`, `components/`, `managed_components/espressif__esp_matter/`, or ESP-IDF component paths.
- Use when code touches controller lifecycle, discovery, subscriptions, UI state, device catalogs, hardware drivers, build/flash/monitor, or long-running serial logs.
- Prefer existing project boundaries over convenience coupling.

## Decision Order

1. Correctness, lifecycle safety, and hardware/protocol constraints.
2. Centralized state machines over scattered booleans and cross-module state.
3. Strong boundaries: orchestration, domain state, protocol adapters, UI adapters, and platform/hardware code.
4. Simplicity: KISS/YAGNI, no one-off wrappers, no speculative compatibility layers.
5. Idiomatic error handling for the codebase being edited.
6. Flat control flow with early returns and narrow cleanup paths.

## Workflow

1. Identify whether the file is app ESP-IDF code, Matter/CHIP code, UI code, or device/hardware code.
2. Read nearby code before changing boundaries; do not invent a new layer from file size alone.
3. Find the owner of state and keep mutation there.
4. Use ESP-IDF macros in ESP-IDF app/components and `VerifyOr*` macros in Matter/CHIP code.
5. Run the smallest useful validation first, then full `idf.py build` when source layout or compile units changed.
6. For long-running monitor/log sessions, use the `tmux` skill so the main turn does not block.

## Topics

| Topic | Guidance | Reference |
| --- | --- | --- |
| Architecture | Keep orchestration, state, protocol, UI, and platform boundaries clear | [references/architecture.md](references/architecture.md) |
| State Machines | Centralize state transitions and reduce state count | [references/state-machines.md](references/state-machines.md) |
| Error Handling | Use ESP-IDF macros or Matter `VerifyOr*` based on codebase | [references/error-handling.md](references/error-handling.md) |
| IDF Workflow | Build, reconfigure, generated files, requirements, flash, and monitor practices | [references/idf-workflow.md](references/idf-workflow.md) |
| Review Checklist | Fast sustainability check before final answer | [references/review-checklist.md](references/review-checklist.md) |

## References

- Topic files are short and task-focused.
- Prefer source examples from the active ESP-IDF and Matter trees over generic style advice.
