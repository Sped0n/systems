---
urls:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/freertos_idf.html
---

# State Machines

## Goals

- Control the number of states.
- Make transitions explicit and serialized.
- Avoid scattered booleans that create impossible combinations.
- Keep UI status derived from one source of truth.

## Guidance

- Start with a small enum that describes user-visible or lifecycle-visible states.
- Keep retry counters, pending work bits, timers, and callbacks in one orchestration module.
- Serialize backend work through one queue/task/timer path when concurrency is not required.
- Prefer `IDLE`, `FETCHING`, `DISCOVERING`, `SUBSCRIBING`, `FAILED`, and domain-specific terminal states over many parallel flags.
- Derive helpers such as `state_reload_enabled(state)` instead of storing `reload_enabled` separately.
- Keep command-in-progress state local to the command path unless UI truly needs it globally.
- Preserve old usable state when refresh fails if local control can continue safely.

## Transition Rules

- Transition before starting observable work if UI should show progress.
- Transition on callback completion, not on request submission, when async APIs report later success/failure.
- Treat callback success plus missing expected data as a real error at the boundary.
- Prune removed registry entries only when the catalog/discovery source is authoritative.
- Keep retry behavior centralized; avoid per-call hidden retry counters.

## Example Shape

```cpp
enum app_state_t {
    APP_STATE_NOT_PROVISIONED,
    APP_STATE_IDLE,
    APP_STATE_FETCHING,
    APP_STATE_DISCOVERING,
    APP_STATE_SUBSCRIBING,
    APP_STATE_RELOAD_FAILED,
};

static bool app_state_can_reload(app_state_t state)
{
    return state == APP_STATE_IDLE || state == APP_STATE_RELOAD_FAILED;
}
```

## Anti-Patterns

- `fetch_in_progress`, `discovery_in_progress`, `subscriptions_in_progress`, and `reload_failed` all stored independently.
- Each module owns its own timer for the same lifecycle.
- UI suppresses updates during busy states, hiding real progress.
- Retry code lives beside every call site instead of the state machine.
