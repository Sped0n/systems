---
urls:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/error-handling.html
  - https://github.com/project-chip/connectedhomeip
---

# Review Checklist

Use before final answer or before proposing a larger refactor.

## Boundaries

- Is state owned by one module?
- Is UI consuming a snapshot/adapter instead of protocol internals?
- Are capability handlers limited to concrete capability behavior?
- Is orchestration outside capability-specific modules?
- Did the change avoid managed components unless explicitly requested?
- Did the change avoid generated files such as `sdkconfig`, dependency locks, and board-manager generated output unless explicitly requested?

## State

- Can several booleans become one enum state?
- Are impossible state combinations prevented by construction?
- Are retries, timers, callbacks, and work bits centralized?
- Does failure preserve usable old state when safe?

## Error Handling

- ESP-IDF app/component code uses `ESP_RETURN_*` or `ESP_GOTO_*` where appropriate.
- Matter/CHIP code uses `VerifyOr*` macros where appropriate.
- Cleanup has one obvious path.
- Logs add boundary context and are not noisy in polling/report paths.

## Simplicity

- No one-off wrapper/helper function was added without clear readability value.
- No speculative compatibility shim was added without persisted data, shipped behavior, or external consumers.
- File moves updated includes directly instead of adding forwarding headers.
- Control flow is flat enough to read the happy path at the left margin.

## Validation

- `git diff --check` ran after edits.
- `REQUIRES` and `PRIV_REQUIRES` do not depend on `CONFIG_xxx`.
- `idf.py reconfigure` ran if source files moved or CMake source discovery changed.
- `idf.py build` ran for compile-affecting changes.
- Hardware validation gaps are stated clearly when behavior depends on the device.
