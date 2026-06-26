---
urls:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/tools/idf-py.html
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/build-system.html
---

# IDF Workflow

## Build and Reconfigure

- Run `idf.py build` from the project root or app directory that owns `CMakeLists.txt`.
- Run `idf.py reconfigure` after moving source files when `SRC_DIRS` or generated Ninja state still references old paths.
- Run `git diff --check` after edits.
- Do not edit generated `sdkconfig`, `dependencies.lock`, `managed_components/`, or generated board-manager output unless explicitly requested.
- Treat Kconfig warnings from dependencies as non-blocking only after verifying the build completes.

## Generated Files and Managed Components

- Do not manually modify generated files such as `sdkconfig`, board-manager generated code, dependency locks, or generated build output.
- Do not edit `managed_components/` unless the user explicitly asks; prefer app code or local app components.
- If generated state is stale after a source move, run `idf.py reconfigure` instead of editing generated Ninja/CMake files.
- If dependency resolution changes lockfiles unexpectedly, call it out; do not hide it as part of an app-code change.

## Component Requirements

- `REQUIRES` and `PRIV_REQUIRES` must not depend on `CONFIG_xxx` options.
- ESP-IDF expands component requirements before configuration is loaded.
- Include paths, source files, compile options, and other component variables can depend on `CONFIG_xxx` when the build system supports that timing.
- If a dependency is optional by config, keep the requirement unconditional or split the code/component boundary so the requirement graph is stable.

## Flash and Monitor

- Flashing changes hardware state; do it only when the user asked for device validation or when the task clearly requires it.
- Monitor can run indefinitely; do not block the agent turn on a foreground `idf.py monitor`.
- Use the `tmux` skill for `idf.py monitor`, serial logs, test watchers, or long-running repro sessions.

## Monitor Practice

- Capture recent output instead of streaming forever.
- Search logs for reset reason, panic, assert, heap, task watchdog, Matter subscription, RainMaker fetch, and app state transitions.
- If monitor output implies a crash before `app_main`, inspect linker fragments, BSS/PSRAM placement, early static initializers, and board-manager generated init.
- If monitor output implies async fetch failure, verify callback result, returned list ownership, retry state, and whether old local cache should remain usable.
