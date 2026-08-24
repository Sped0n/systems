---
name: project-chip
description: Practical Matter, CHIP, and esp_matter protocol guidance. Use when writing, reviewing, or debugging Matter controller lifecycle, discovery, subscriptions, device catalogs, clusters, protocol callbacks, or CHIP_ERROR and VerifyOr* handling; invoke esp-idf too for platform, build, or hardware work.
---

# Project CHIP

Use for Matter, CHIP, and esp_matter protocol behavior. For ESP-IDF, FreeRTOS, RainMaker, LVGL, hardware, component requirements, build, flash, or monitor work, also invoke `esp-idf`.

## Scope

- Own Matter/CHIP/esp_matter protocol behavior, controller lifecycle, commissioning-facing flows, discovery, subscriptions, device catalogs, cluster interactions, and protocol callbacks.
- Prefer source examples and conventions from the active Matter and esp_matter trees. Do not change generated or managed dependency code unless explicitly asked.
- Keep app-specific domain and platform behavior outside upstream-style CHIP modules.

## Architecture and Lifecycle

- Keep controller lifecycle, asynchronous requests, callback completion, retries, and subscription ownership in one protocol orchestration module.
- Separate an app-owned catalog or identity source from live protocol discovery. Prune entries only when its source is authoritative.
- Centralize state mutation. Use a small lifecycle enum instead of independent `fetching`, `discovering`, `subscribing`, and `failed` flags; derive UI-facing status from it.
- Transition before observable work begins and on callback completion. Treat successful callbacks with missing expected data as boundary errors.
- Capability handlers implement concrete behavior; they do not start global discovery, retry, or subscription loops. Expose snapshots or narrow queries instead of leaking controller internals to UI or domain code.
- Preserve usable old catalog or device state after refresh failure when local control can continue safely.

## Errors

- In Matter/CHIP code, prefer `VerifyOrReturn`, `VerifyOrReturnError`, `VerifyOrExit`, and related macros.
- Use `VerifyOrReturnError(condition, CHIP_ERROR_...)` for guards in `CHIP_ERROR` functions; use `VerifyOrReturn(condition)` only when ignoring an invalid callback is correct.
- Use `VerifyOrExit` for shared cleanup. Validate early and keep one obvious cleanup path.
- Do not introduce ESP-IDF error macros into upstream-style CHIP code unless the local file convention requires it; mixed boundary code may need both skills' guidance.

## Review

- One owner controls controller state, retries, timers, work, and subscriptions for each lifecycle.
- Catalog identity and live discovery are not conflated.
- Protocol callbacks do not directly render UI or mutate unrelated platform state.
- Capability-specific code does not own global lifecycle loops.
- Validate the smallest relevant target first; for compile-affecting ESP-IDF integration changes, invoke `esp-idf` and run `idf.py build`.
