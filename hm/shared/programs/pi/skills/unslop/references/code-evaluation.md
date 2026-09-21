# Code evaluation

Use behavior checks and code measurements to compare a baseline with a proposed simplification. This workflow follows the ideas in the [Earendil article](https://earendil.com/posts/measuring-code-sloppiness/) and [SlopCodeBench paper](https://arxiv.org/html/2603.24755v1). The evaluator is a local adaptation, not the official benchmark or its hidden tests.

## What the benchmark measures

SlopCodeBench evaluates agents across successive changes to a codebase, tracking correctness and whether code quality deteriorates as requirements accumulate. Keep these measures separate:

- **Correctness:** do the required tests and builds pass after each change?
- **LOC change:** how much code was added or removed? Fewer lines are not automatically better.
- **Verbosity (V):** the fraction of covered lines flagged as redundant or duplicated. A line counted by both checks contributes only once.
- **Structural erosion (E):** the fraction of complexity-weighted function mass in functions whose cyclomatic complexity exceeds 10.

```text
V = |flagged lines ∪ clone lines| / analyzed LOC
mass(f) = CC(f) × sqrt(SLOC(f))
E = sum(mass(f) where CC(f) > 10) / sum(mass(f))
```

`CC` means cyclomatic complexity. Function `SLOC` excludes blank lines and comments; `analyzed LOC` includes nonblank comment lines. A zero denominator produces `null`, not a perfect score. Do not combine correctness, V, and E into an invented overall score.

## Human reference and desirable scores

The paper reports these results for **48 maintained human Python repositories** (mean ± standard deviation):

| Measure | Human reference | Mathematical minimum |
|---|---:|---:|
| Verbosity | 11% ± 7 percentage points | 0% |
| Structural erosion | 31% ± 12 percentage points | 0% |

These are observed averages, **not an ideal-human threshold or a pass/fail standard**. The repositories are not matched human solutions to the benchmark tasks. Zero verbosity means no detected redundancy; zero erosion means no measured function mass lies above the complexity threshold. Neither guarantees good design.

Aim for passing behavior checks, adequate coverage, and justified improvements relative to the baseline. Preserve necessary complexity and safeguards rather than optimizing toward zero. The local scoring conventions are not calibrated against the paper, so do not directly rank these results against the human averages, especially across different languages.

Treat the CC 10 boundary as a review signal, not a refactoring target. Do not create
one-use wrappers merely to move decisions into another function or below the threshold.
Extract a helper when it gives a durable responsibility a useful name, is independently
testable, is reused, or hides a genuinely separate mechanism. Otherwise keep cohesive
control flow together and accept the measured complexity.

## Measure and compare

The evaluator emits a detailed JSON report; the agent owns behavior checks and before/after comparison. Requires uv, Python 3.13+, and Git on Linux or macOS. Resolve these examples from the skill directory; use `--help` for other options.

```bash
# Scan a source directory.
uvx --from ast-grep-py python scripts/evaluate.py /path/to/project/src > /tmp/unslop-baseline.json

# Scan one file.
uvx --from ast-grep-py python scripts/evaluate.py /path/to/project/src/main.cpp > /tmp/unslop-file.json

# Select C++ sources and headers, excluding generated code.
uvx --from ast-grep-py python scripts/evaluate.py /path/to/project \
  --include 'src/**/*.cpp' --include 'src/**/*.h' \
  --exclude 'src/generated/**' --language cpp > /tmp/unslop-cpp.json
```

Reports include aggregate scores, a `files` breakdown, and a focused
`highComplexityFunctions` list for functions above CC 10.

Patterns are relative to the scan root; exclusions win. Git ignores apply by default.

1. Choose a focused scope and the project's real tests and builds. Preserve existing work and record pre-existing failures. Review commands before running them; this workflow does not authorize destructive tests or production/hardware operations.
2. Run behavior checks and save the baseline report. Store reports outside the measured scope under distinct names; do not overwrite evidence.
3. Make one scoped simplification, rerun the same checks, and save another report. Ensure checks do not unintentionally modify measured source. Keep scope, filters, language selection, rules, tool versions, and limits consistent; inspect report settings and source hashes rather than assuming comparability.
4. Compare LOC, V, and E with their raw counts and coverage. Explain scope changes, retain failed rounds in the assessment, and inspect the diff for costs the metrics miss. Do not weaken tests or safeguards to improve a score.

## Interpret coverage before scores

A successful evaluator exit means a report was produced, not that code is valid or behavior checks passed. Inspect completeness, coverage, skipped functions, and errors before drawing conclusions. Unsupported languages and parser failures can bias results substantially; excluded or Git-ignored code is outside the measured scope. Choose generated-code exclusions deliberately.

Verbosity covers error-free files. Erosion can also use recognized functions from partially parsed files when their ranges do not overlap detected syntax errors. Remaining errors keep the report partial: accepted functions do not prove that the parser found every function or interpreted macros correctly. Do not present partial results as a whole-scope score or an unqualified success.

Treat findings as review prompts. Identical branches may still need their condition evaluated for side effects, and a lower erosion score does not establish better ownership or design. Report behavior-check results and concrete tradeoffs alongside measurements; stop when the requested outcome and its proof are complete.
