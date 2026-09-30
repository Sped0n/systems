---
name: friendly-python
description: Write, refactor, and review Python code, including APIs, CLI parsing, exceptions, data handling, tests, and application boundaries.
metadata:
  source: "https://github.com/PsiACE/skills"
  commit: "2265aed05caf199426a8062461e2c9901be996d8"
  adaptation: "Merged friendly-python and piglet references into one task-routed Python skill; local boundary and complexity guidance."
---

# Friendly Python

Use the project's supported Python version and established conventions. Keep inputs, normal results, failure modes, and resource ownership explicit. Load only the references relevant to the change; the examples illustrate choices, not mandatory architecture.

## Choose a reference

| When working on | Read |
| --- | --- |
| Signatures, naming, package exports, or external-call timeouts | [Python conventions](references/python-conventions.md); for local names and scope, [Variables and naming](references/variables-and-naming.md) |
| Public APIs or CLI arguments | [API design](references/api-design.md) or [CLI argparse](references/cli-argparse.md), respectively |
| Exception boundaries, chaining, or cleanup on failure | [Error handling](references/error-handling.md); for language-level patterns, [Exception examples](references/exceptions-handling.md) |
| Branching, loop structure, or iterator choices | [Conditions](references/if-else-and-branches.md) or [Loops and iteration](references/loops-and-iteration.md), respectively |
| Numeric/string operations or container selection | [Values and containers](references/values-and-containers.md) |
| Function contracts and return shapes | [Functions and returns](references/functions-and-returns.md) |
| Decorators and wrapped signatures | [Decorators](references/decorators.md) |
| Imports, module cycles, files, or paths | [Imports and structure](references/imports-and-structure.md) or [Rules and file I/O](references/rules-and-file-io.md), respectively |
| Constructors, inheritance, or composition | [OOP design](references/oop-design.md), [Substitutability](references/solid-python.md), or [Reuse and composition](references/reuse-composition.md), as applicable |
| An existing extension mechanism | [Extension architecture](references/extension-architecture.md); do not add extension points without a real requirement |
| Transport, domain, persistence, or background-job boundaries | [Application architecture](references/application-architecture.md) |
| Test scope, isolation, or time control | [Testing](references/testing.md) |
| Repeated validation, leaked internals, or placeholder failure handling | [Boilerplate review](references/kill-ai-slop.md) |
| EAFP, edge cases, or assignment expressions | [Edge cases](references/edge-cases.md) or [Walrus operator](references/walrus-operator.md), respectively |
| Porting patterns from another language | [Pythonic portability](references/portability-pythonic.md) |
| A broad Python quality review | [Review checklist](references/review-checklist.md); consult [Principles](references/principles.md) only for unresolved design tradeoffs |

Validate untrusted input once at the owning boundary. Reuse an installed schema library for structured payloads when it fits; small CLI scripts do not need a new dependency for ordinary argument or protocol checks. Preserve domain invariants and distinguish malformed input from legitimate empty results.
