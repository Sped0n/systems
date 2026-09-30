---
urls:
  - https://go.dev/blog/context-and-structs
  - https://go.dev/blog/error-handling-and-go
---

# Orchestration

Keep complex sequencing readable while separating genuinely distinct capabilities.

- Give each use case an identifiable entry point: a package function or method according to local style. Related use cases can have separate entry points; do not force unrelated flows through one executor.
- Keep dependencies and lifecycle wiring discoverable, including background-worker startup, cancellation, and shutdown coordination.
- Let orchestration own order, branching, and propagation of errors. Extract details when they name a durable responsibility, hide a separate mechanism, or support reuse or independent testing—not simply to shorten a function.
- Keep implementation helpers unexported unless callers need a stable contract.
- Add stage-intent comments where ordering or rationale is not evident from the calls. Do not annotate every obvious step.
- Split packages along real domain seams when that reduces coupling, not by file size.
- Convert errors to HTTP/gRPC responses at transport boundaries; do not teach core capabilities about wire status codes.

## Review

Can a reader follow the primary flow and its failure paths? Are extracted capabilities coherent rather than one-use wrappers? Are worker lifecycle and cleanup visible? Does each added boundary reduce more complexity than it creates?
