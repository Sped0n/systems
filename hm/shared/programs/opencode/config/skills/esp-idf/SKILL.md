---
name: esp-idf
description: Practical ESP-IDF, FreeRTOS, ESP RainMaker, LVGL, board, and hardware guidance. Use when writing, reviewing, debugging, building, reconfiguring, flashing, or monitoring ESP-IDF applications and components, especially CMake component requirements, generated files, ESP_* error macros, platform state, and device drivers.
---

# ESP-IDF

Use for ESP-IDF platform and application work. For Matter/CHIP protocol behavior, controller lifecycle, discovery, subscriptions, or device catalogs, also invoke `project-chip`.

## Scope

- Own ESP-IDF, FreeRTOS, ESP RainMaker, LVGL, board/platform, peripherals, power, sensors, buses, provisioning, build, flash, and monitor work.
- Keep app hardware behavior outside dependency and vendor code. Do not edit `managed_components/` or generated files unless explicitly asked.
- Prefer existing component and platform boundaries over new wrappers or layers.

## Architecture and State

- Keep platform/hardware policy near its owner; UI renders snapshots and sends intents, not protocol or hardware decisions.
- Centralize mutation of app/platform state in one owner. Derive UI busy, error, and enabled states from its enum rather than parallel booleans.
- Keep timers, task/queue work, callbacks, retries, and cleanup for one lifecycle in one orchestration path. Serialize work unless concurrency is required.
- Transition before observable work begins; transition on asynchronous completion, not request submission. Preserve usable prior state after a failed refresh when safe.
- Do not let LVGL screens own driver state, and do not scatter GPIO or power policy through UI callbacks.

## Errors

- In ESP-IDF app and component code, prefer `ESP_RETURN_ON_FALSE` and `ESP_RETURN_ON_ERROR` for guards and direct returns.
- Use `ESP_GOTO_ON_FALSE` or `ESP_GOTO_ON_ERROR` only when acquired resources require one cleanup label.
- Validate inputs first, keep the happy path flat, and log at the boundary that adds context. Avoid noisy polling-path logs.

## Build and Device Workflow

- Run `idf.py build` from the project or app root that owns `CMakeLists.txt`; run the smallest relevant check first.
- Run `idf.py reconfigure` after source moves or CMake source-discovery changes. Do not repair generated Ninja or CMake state manually.
- `REQUIRES` and `PRIV_REQUIRES` must not depend on `CONFIG_xxx`; the component graph is expanded before configuration is loaded.
- Do not manually modify `sdkconfig`, `dependencies.lock`, generated board-manager output, `managed_components/`, or build output unless explicitly requested. Report unexpected lockfile changes.
- Flashing changes hardware state; do it only when requested or clearly required. Use the `tmux` skill for `idf.py monitor`, serial logs, and other long-running sessions.
- For device failures, capture recent logs and inspect reset reason, panic, heap, task watchdog, startup placement, and app state transitions.

## Review

- One module owns each platform state and lifecycle.
- Driver, board, and power policy do not leak into UI or unrelated feature code.
- Component requirements are configuration-independent.
- Generated and managed files remain untouched unless in scope.
- Run `git diff --check`; run `idf.py build` for compile-affecting changes and state any hardware-validation gap.
