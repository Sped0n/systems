---
urls:
  - https://go.dev/wiki/CodeReviewComments
---

# Modular Go Review Checklist

Apply these questions to the affected behavior, not as a mandate to redesign unrelated code.

## API and Boundaries

- Are package responsibilities and supported operations clear?
- Does each export or interface serve a stable caller contract?
- Are ownership, concurrency, and error semantics documented where callers need them?
- Are helpers local unless a concrete shared responsibility justifies extraction?

## State and Lifecycle

- Can transformations remain stateless?
- Are mutation ownership and valid transitions explicit?
- Does synchronization protect shared invariants with clear lock scope?
- Is acquisition paired with release on failure, cancellation, and shutdown?
- Does cancellation stop work, and does explicit cleanup release owned resources?
- Can teardown coordinate all owned goroutines and late work safely?

## Construction and Orchestration

- Is construction explicit without speculative options or builders?
- Can the use-case sequence and its failure paths be followed directly?
- Does each helper or package boundary own a distinct responsibility?
- Do comments explain ordering or rationale rather than restating calls?

## Transport Handlers

- Is protocol mapping distinguishable from business behavior?
- Are dependencies supplied explicitly rather than read from mutable globals?
- Is error-to-status conversion consistent at the transport boundary?
