---
urls:
  - https://go.dev/blog/package-names
  - https://go.dev/doc/effective_go
---

# Module Boundary

Keep package responsibilities and exported contracts understandable without adding boundaries for their own sake.

## Guidance

- Expose the cohesive operations callers need. Keep helpers and assembly details unexported; several related entry points can form one clear API.
- Prefer small, behavior-focused interfaces at the consumer that needs them. Keep concrete types when no substitution boundary is needed; do not hide every implementation behind an interface.
- Document exported behavior and caller expectations, especially ownership, concurrency, and failure contracts. A wide adapter interface may be appropriate at an integration boundary, but breadth needs a real consumer.
- Keep pure helpers local unless actual cross-package reuse justifies extraction. Use names that describe the domain or capability; avoid catch-all `common`, `utils`, or automatically created `xxxutil` packages.
- Begin construction with a function and explicit parameters or a configuration struct. Use option functions or a builder only when they clarify actual optionality, staged construction, or cross-field validation.
- Split along responsibility seams when it reduces coupling. A package's size or multiple exported functions alone do not establish a design problem.
- Inline single-consumer adapters when a separate abstraction adds no useful contract.

## Responsibility Seams

- **Initialization vs. serving:** Keep dependency wiring distinguishable from request handling; neither requires its own package automatically.
- **Protocol vs. domain:** Keep wire-format translation and business decisions separately understandable.
- **State lifecycle vs. operations:** Give registries and resource ownership a clear owner without imposing an ID-based manager on all callers.
- **Reusable helper vs. domain package:** Extract only when consumers share a stable responsibility, not merely similar-looking code.

## Review

Can callers identify the supported operations and their contracts? Does each export, interface, constructor option, and package boundary serve a concrete need? Are helper names specific enough to reveal what they own?
