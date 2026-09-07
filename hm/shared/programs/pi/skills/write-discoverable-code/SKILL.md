---
name: write-discoverable-code
description: Write and review searchable code with Tiger Style naming, explicit contracts, and locally understandable control flow.
license: MIT
metadata:
  source: "https://github.com/modem-dev/skills"
  commit: "edcdedb38a545f67c065f4084b3627517f0d79cf"
  style_reference: "https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md"
---

# Write Discoverable Code

Make domain concepts, their implementations, and their contracts easy to find through plain-text search and verify by reading nearby code. Apply Tiger Style's precise naming, explicit invariants, and emphasis on local reasoning. Follow the repository's language conventions and safety policy; do not impose Zig syntax or TigerBeetle-specific allocation, assertion-count, or line-count rules on unrelated projects.

## Get the nouns and verbs right

- Search existing vocabulary before introducing a name. Use one canonical spelling per concept across code, configuration, tests, and documentation. Do not overload a domain term with a second, context-dependent meaning.
- Name entities with precise nouns and operations with precise verbs. Choose vocabulary that works unchanged in documentation and conversation: `replica.pipeline` describes a concept more clearly than `replica.preparing`.
- Prefer full words over abbreviations. Use established domain acronyms with the repository's capitalization convention. Prefer supported long-form flags in scripts; short flags are for interactive convenience.
- Put the concept first and units or qualifiers last, from most to least significant: `latency_ms_min` and `latency_ms_max`, not `min_latency_ms` and `max_latency_ms`. Adapt casing to the language, and preserve established public names.
- Use parallel names for parallel roles: `source_offset` and `target_offset`, not `src_offset` and `destination_pos`. Prefer symmetry when equally precise; do not distort meaning just to match character counts.
- Distinguish `index`, `count`, and byte `size`. Make units, rounding, inclusive or exclusive bounds, and ownership visible in names or types when they affect correctness.
- Design public names from the caller's vocabulary, not hidden implementation terminology. Use named arguments or an options value when same-typed positional arguments are easy to swap; do not introduce a builder solely for naming.

## Give concepts clear homes

- Name files after the capability or responsibility they own rather than generic labels such as `utils` or `helpers`.
- Keep each concept's authoritative definition near the code that owns its invariant. Reuse or move shared behavior instead of copying it; do not add wrappers solely to create search hits.
- Order code for a top-down first read where language and repository conventions allow: entry points before their subordinate helpers, related operations together.
- For a helper or callback dedicated to one operation, retain that operation's name when the relationship would otherwise be hidden: `read_sector` and `read_sector_callback`. Do not give shared helpers a misleading single-caller name.
- Keep functions small enough to understand as a whole. Let orchestration own branching and state transitions while helpers own cohesive calculations or operations; avoid fragmenting a clear function into trivial indirections.

## Make contracts locally checkable

- Keep variable scope small. Compute values and check preconditions close to their use; avoid redundant state and aliases that can drift out of sync.
- Express programmer invariants in types or assertions where practical. Handle invalid external input and expected operating failures through normal error paths, not assertions. Do not add assertions merely to meet a quota.
- Make limits on input-driven work, queues, retries, and buffers explicit at the owning boundary. Distinguish intentional long-lived loops from accidentally unbounded work; use limits justified by the real contract rather than arbitrary caps.
- Keep ownership, cleanup, and state transitions visible together. Do not rely on a precondition surviving a suspension or concurrent mutation without revalidation or synchronization.
- Prefer control flow whose valid, invalid, and boundary cases can be checked independently. Split compound conditions when that makes the cases clearer, not as a mechanical rewrite of every boolean expression.

## Leave searchable evidence

- Document constraints that names and types cannot express: ownership, ordering, time basis, bounds, and non-obvious rationale. Put that context at the relevant definition or boundary.
- Explain why a design is correct, not just what it does. For a non-obvious test, describe the behavior being proved and how the setup exposes a failure. Use clear prose and the domain phrase a reader is likely to search for.
- Keep stable event names, flags, error codes, and diagnostic prefixes as complete literals where practical so a search leads to their definition or emission site. Keep runtime values separate and preserve localization conventions.

## Changes and verification

- For a rename or move, search old names, likely synonyms, configuration keys, diagnostics, tests, and documentation within the affected scope.
- Preserve compatibility for externally consumed names, persisted keys, or public APIs unless a breaking change is authorized. Account for intentional aliases rather than blindly replacing every match.
- Check that old implementation copies are gone and that retained references are intentional.
- Verify that a search using the domain term finds the public behavior and its authoritative implementation, with crucial ownership and constraints nearby.
