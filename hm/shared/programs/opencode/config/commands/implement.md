---
description: Implement a piece of work based on a spec or set of tickets.
agent: build
---
<!-- Source: mattpocock/skills@391a2701dd948f94f56a39f7533f8eea9a859c87 skills/engineering/implement/SKILL.md -->

Record the current `HEAD` commit before editing. If the input is a local ticket, ensure its effort `.claims/` directory exists, atomically claim it with a non-recursive `mkdir .claims/<NN>`, and set its status to `claimed` before editing. If the claim already exists, stop because another session owns it.

Implement the work described by the user in the spec or ticket.

Load and apply the `tdd` skill where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, load and apply the `code-review` skill using the recorded commit as its fixed point. If implementation produced no diff, report that instead of invoking an empty review. After implementation and review pass, check the local ticket's acceptance criteria and set its status to `closed`. For a Wayfinder ticket, also append its `## Resolution` and update the map under the effort's atomic `.map-lock` protocol. Remove the ticket's claim only after all required updates succeed. Leave a failed or interrupted ticket claimed with a short note so ownership is explicit.

$ARGUMENTS
