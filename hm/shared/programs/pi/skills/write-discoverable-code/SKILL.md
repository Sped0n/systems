---
name: write-discoverable-code
description: |
  Rules for writing code that coding agents (and humans) can find and understand through
  plain-text search. Apply whenever writing or renaming code: functions, types, constants,
  files, error messages, doc comments.

  Grounded in measurement: agents navigate by plain-text search, not by AST or
  language server, so every identifier is a search query and every search miss
  costs wasted reads.
license: MIT
metadata:
  source: "https://github.com/modem-dev/skills"
  commit: "edcdedb38a545f67c065f4084b3627517f0d79cf"
  style-source: "https://github.com/tigerbeetle/tigerbeetle"
  style-commit: "97c7a8ef385270ebe0e1b75959d3d21d134629df"
---

# Write Discoverable Code with Tiger Style

Coding agents navigate through text search and local reads. A definition, its invariants, its rationale, and the terms used to find it must therefore meet at one searchable location. Apply the following coding rules, adapted from [Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md), whenever writing or renaming functions, types, constants, files, errors, and comments.

Tiger Style orders its goals as **safety, performance, and developer experience**. Discoverability serves all three: a reader who can find code, its bounds, and its reasoning can verify it before it fails in production.

## Safety

- Use simple, explicit, bounded control flow. Avoid recursion unless a hard bound and the project's domain justify it. Add abstractions only when they make the domain clearer and reduce total complexity. If removing, inlining, renaming, or moving a helper or layer causes no concrete loss of clarity, ownership, reuse, or invariant enforcement, simplify it.
- Put an explicit limit on every loop, queue, batch, retry, input, and resource use. State the unit and ownership at the definition or boundary that enforces the limit.
- Assert programmer-error conditions at function boundaries: argument validity, return-value validity, preconditions, postconditions, and invariants. Use the language's appropriate assertion facility, not assertions to handle expected operating errors.
- Pair important assertions at independent boundaries, especially before writing data and after reading it. Assert both the valid space you expect and invalid space you reject. Split compound assertions so failures identify the violated condition.
- Handle operating errors explicitly. Never hide or discard an error path. Use positive conditions and complete branches where they make valid and invalid cases clear.
- Keep variable scope small. Compute and validate a value close to where it is used; do not create aliases or duplicate state without a clear reason.
- Keep functions small enough to inspect as one unit. Tiger Style's hard limit is 70 lines; where a repository has a different documented limit, follow it. Split by moving non-branching, preferably pure computation into helpers while keeping related control flow and state transitions visible together.
- Make external interaction occur at the program's controlled pace where possible. Batch work and bound per-period effort rather than reacting unboundedly to every incoming event.

## Performance

- Sketch the design's network, disk, memory, and CPU costs before implementation. Consider both bandwidth and latency, then optimize the slowest material resource first after accounting for frequency.
- Batch accesses to amortize network, disk, memory, and CPU costs. Separate control-plane coordination from data-plane work when that makes batching and bounds clearer.
- Be explicit in hot paths. Extract a hot loop when that makes its primitive inputs, bounds, and redundant work easy for the compiler and reviewer to see.
- Prefer the project's existing toolchain and dependencies. Add a dependency only when its safety, performance, and maintenance cost is justified by a concrete need.

## Developer Experience and Discovery

- Get nouns and verbs right. Use the repository's established naming convention, avoid abbreviations, and give names enough domain context to search uniquely. Add units and qualifiers to numeric names, with the significant concept first and the unit last, such as `latency_ms_max`.
- Use one canonical spelling for each domain concept. Reuse the codebase vocabulary rather than creating synonyms. Rename behavior when its behavior or audience changes. When changing a concept, search for its old names, synonyms, literals, configuration keys, tests, and documentation; account for every live occurrence rather than updating only the initiating example.
- Give each searchable concept one named home and one definition site. Move shared code rather than copying it. Name files after the question they answer, not generic roles such as `utils`, `helpers`, or `types`.
- Put a concise comment at each exported or externally meaningful definition when the type and code cannot express a crucial constraint: unit, ordering, time basis, ownership, bound, or rationale. Write the natural-language phrase a reader will search for.
- Keep event names, flags, error codes, and error-message prefixes as complete literals. A log message must search directly to its throw or emission site.
- Put the important path first: main entry points, central types, and the functions a reader needs to follow. Keep orchestration thin so searches land one hop from the implementation.
- Design public APIs from the caller's search path. Names should reveal the capability, configuration should expose meaningful choices, errors should guide recovery, and invalid usage should be difficult to express.
- Explain why and how where a future reviewer cannot infer it. Comments are precise prose, not a substitute for code or assertions.
- Use the repository formatter. Unless the repository specifies otherwise, keep lines at or below 100 columns and use braces consistently for conditionals.

## Completion Check

1. Can one search find each new public or externally meaningful behavior and its definition?
2. Can a caller find each capability without knowing its implementation terminology?
3. Are bounds, units, invariants, error paths, and ownership explicit at the relevant boundary?
4. Are names descriptive, canonical, unambiguous, and consistent with the repository's language convention?
5. Do comments explain the non-obvious why, and do literal logs and errors search to their source?
6. Did the design consider its network, disk, memory, and CPU costs?
7. Did moved code disappear from its old home and did changed behavior receive an accurate name?
