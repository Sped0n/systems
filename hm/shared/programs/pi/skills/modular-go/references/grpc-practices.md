---
urls:
  - https://grpc.io/docs/languages/go/basics/
  - https://go.dev/blog/context
---

# gRPC Practices

## Goals

- Keep transport concerns isolated from domain logic.
- Make gRPC services easy to test without starting a real server.

## Guidance

- gRPC service implementations translate protocol requests into domain operations and map their results back to responses.
- Keep business decisions in explicitly supplied domain functions or objects; do not introduce a manager or handler type solely to delegate a call.
- Convert domain errors to gRPC status codes at the handler boundary in one centralized place.
- Use `context.Context` from the incoming RPC for cancellation and deadline propagation; do not create detached contexts.
- Keep server initialization and request handling separately understandable. Split packages only when distinct responsibilities or consumers justify that boundary.
- Register services with explicit domain dependencies; avoid global state or init-time registration.

## Structuring a gRPC Package

One possible layout, when it fits the project's existing structure:

- `server.go`: Server constructor, listener setup, graceful shutdown.
- `service.go`: Handler methods implementing the generated interface.
- Keep proto-generated code in its own module or a `proto/` subdirectory; do not mix generated and hand-written code.

## Review Bullets

- Does each handler method fit the pattern: unmarshal → delegate → marshal?
- Is business logic free of any gRPC-specific types (`codes`, `status`, proto messages)?
- Is error-to-status conversion centralized rather than scattered across handlers?
- Are domain dependencies injected via the constructor, not accessed through globals?
- Is `context.Context` from the RPC propagated to downstream calls?
