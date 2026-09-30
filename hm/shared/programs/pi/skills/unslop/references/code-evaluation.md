# Code evaluation

Use behavior checks and Lizard measurements to compare a baseline with a proposed simplification. Requires `uvx` on `PATH`. Lizard supports multiple languages, including Python, Rust, Go, and C/C++; consult `uvx lizard --help` for current language and output options.

## Measure and compare

```bash
uvx lizard --version

# Baseline: choose the source scope and exclusions deliberately.
uvx lizard --csv -i -1 /path/to/project/src \
  -x '*/generated/*' > /tmp/unslop-before.csv

# After the scoped change: use the same tool version, scope, and settings.
uvx lizard --csv -i -1 /path/to/project/src \
  -x '*/generated/*' > /tmp/unslop-after.csv

# Focused review of C/C++ complexity warnings.
uvx lizard -l cpp -C 10 -w /path/to/project/src
```

`--csv` reports per-function measurements. `-i -1` disables warning-count failures for measurement runs; it does not turn execution failures into success. Without it, Lizard can exit nonzero when warning thresholds are exceeded. Treat warnings separately from tool failures and behavior-check results.

1. Choose a focused scope and the project's real tests and builds. Preserve existing work and record pre-existing failures. Review commands before running them; this workflow does not authorize destructive tests or production/hardware operations.
2. Run behavior checks and save a baseline report outside the measured scope. Record the Lizard version; if versions differ between runs, rerun both with the same version (`uvx --from 'lizard==<version>' lizard …`). Keep distinct report names rather than overwriting evidence.
3. Make one scoped simplification, rerun the same checks, and save another report. Keep scope, exclusions, language selection, tool version, and thresholds consistent. Lizard honors Git ignores by default; review ignored and generated sources deliberately.
4. Compare non-comment lines (NLOC), cyclomatic complexity (CCN), token count, and parameter count for affected functions. Account for renamed, added, and removed functions rather than comparing only surviving rows. Inspect the diff for costs these measurements miss.

## Interpret the evidence

A successful scan does not prove compilation, correctness, complete parsing, or good design. Inspect whether expected files and functions appear; unsupported languages, macro-heavy code, and parser limitations can bias measurements. Empty or partial output is not a whole-scope success.

Lizard measures complexity and size, not redundancy-based verbosity or structural erosion. Do not invent equivalent scores or compare its output with SlopCodeBench's human-reference averages.

Treat thresholds as review signals, not refactoring targets. Do not add one-use wrappers merely to relocate decisions below a threshold. Extract a helper when it names a durable responsibility, supports independent testing, is reused, or hides a genuinely separate mechanism. Otherwise retain cohesive control flow and justify its complexity.

Preserve safety, compatibility, failure handling, and ownership constraints. Lower counts do not establish better behavior or architecture. Report concrete tradeoffs alongside behavior checks and measurements; stop when the requested outcome and its proof are complete.
