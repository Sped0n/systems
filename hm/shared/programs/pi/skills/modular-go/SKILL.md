---
name: modular-go
description: Design and review Go package APIs, interface boundaries, mutable state, lifecycle management, orchestration, and gRPC/HTTP handlers.
metadata:
  source: "https://github.com/PsiACE/skills"
  commit: "2265aed05caf199426a8062461e2c9901be996d8"
  adaptation: "Task-specific routing and contextual architecture guidance instead of mandatory managers, builders, utility packages, or single entry points."
---

# Modular Go

Keep exported contracts intentional and helpers local until a real consumer or responsibility justifies a boundary. Follow the repository's Go version and package conventions. A package can expose several cohesive operations; do not introduce a manager, builder, interface, or utility package solely to match an example.

- When changing exports, interfaces, construction, or package boundaries, read [Module boundary](references/module-boundary.md).
- When changing mutable state, synchronization, cancellation, or resource cleanup, read [State flow](references/state-flow.md).
- When sequencing a complex use case or separating coordination from capabilities, read [Orchestration](references/orchestration.md).
- When implementing gRPC/HTTP translation and transport errors, read [gRPC practices](references/grpc-practices.md).
- For a broad architecture review, read [Review checklist](references/review-checklist.md). Apply questions to the affected scope, not as a mandate to redesign unrelated code.

Design teardown alongside startup. An interface does not synchronize shared state, and context cancellation does not release owned resources by itself.
