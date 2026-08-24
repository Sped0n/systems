---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
metadata:
  source: "https://github.com/mattpocock/skills"
  commit: "9c9f36ccd3995266cd675468af71639c8dde1ec5"
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle — consult them before and during the loop, not after.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Observable behavior boundaries

Test through the narrowest stable public boundary that owns the observable
behavior. Tests should exercise the same interface as callers and avoid private
implementation details or side channels.

Identify the intended behavior boundary before writing a test when it is not
evident from the task or existing coverage. Resolve ordinary choices from the
codebase and its established test patterns. Ask the user only when competing
boundaries would materially change public behavior, architecture, safety,
coverage obligations, or another hard-to-reverse contract.

## Anti-patterns

- **Implementation-coupled** — mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological** — the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth — a known-good literal, a worked example, the spec.
- **Horizontal slicing** — writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead — one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One behavior boundary, one test, one minimal implementation per cycle.
- **Refactoring is not part of the red → green loop.** Review the green change first, then refactor while keeping the suite green.
