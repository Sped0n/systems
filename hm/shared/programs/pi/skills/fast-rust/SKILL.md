---
name: fast-rust
description: Write and review Rust APIs and error boundaries, diagnose build costs, and tune compilation or runtime performance with measurements.
metadata:
  source: "https://github.com/PsiACE/skills"
  commit: "2265aed05caf199426a8062461e2c9901be996d8"
  adaptation: "Task-specific reference routing; general engineering policy remains in AGENTS.md."
---

# Fast Rust

Follow the repository's toolchain, MSRV, and established ownership conventions. Keep error semantics and resource lifetimes visible; optimize measured costs rather than assuming a particular build profile or dispatch technique is faster.

- When designing error types, propagation, or API boundaries, read [Error design](references/error-design.md).
- When diagnosing build time, release profiles, binary size, or measured performance, read [Compilation optimization](references/compilation-optimization.md). Compare equivalent workloads and preserve debugging and deployment requirements.
- When explicitly exploring expression engines or type-level versus dynamic dispatch, read [Type exercise](references/type-exercise.md). It is a specialized exercise, not a default architecture for ordinary Rust code.
