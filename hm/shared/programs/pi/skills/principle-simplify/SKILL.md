---
name: principle-simplify
description: "Apply when sequencing an addition, refactor, or rewrite. Subtract unnecessary complexity, integrate requirements from first principles, and test proposed removals with an ablation experiment and behavior checks. Use uvx lizard when code measurements help."
disable-model-invocation: true
metadata:
  source: "https://github.com/cursor/plugins"
  commit: "2776ddd2355d6d6c8747d3964600f28daf62f049"
  adaptation: "Combines principle-subtract-before-you-add and principle-redesign-from-first-principles with ablation experiments and uvx lizard guidance."
---

# Simplify from Requirements

Start from required outcomes, inputs, constraints, and failure behavior rather than the current architecture. Separate real requirements from implementation assumptions. Prefer deletion, reuse, and consolidation before adding a mechanism.

## Subtract Before You Add

When evolving a system, remove complexity first, then build. Default to subtraction.

Make simplification a continual investment within the requested scope. Leave the design slightly simpler and more capable behind the same or smaller interface than you found it.

- Sequence removal before construction
- Cut before you polish (get to the minimum before investing in quality)
- Design for observed usage, not speculative edge cases
- No speculative validators, parsers, or guards beyond what the spec demands
- Simplify prompts (remove redundant instructions, excessive templates)
- When a reference has no novel content, delete it rather than leaving a stub

Trace actual use before removing dead code, redundant state, duplicated validation, or obsolete references. A suspected redundancy is a hypothesis, not permission to delete it without evidence.

Preserve safety, authorization, data-loss prevention, compatibility, concurrency protection, error handling, and explicitly requested behavior. These are requirements, not speculative guards. Keep checks at real boundaries.

For prose editing, read [Unslop](../unslop/SKILL.md). Preserve distinct constraints and precise meaning when simplifying instructions.

Optimize the whole system, not one file or metric. Moving complexity into callers, configuration, or a new dependency is not necessarily simplification.

## Redesign From First Principles

When integrating a change, don't bolt it onto the existing design. Redesign as if the requirement had been a foundational assumption from the start.

- Read all affected files and callers, and understand the current design
- Ask: "if we were writing this from scratch with this new requirement, what would we build?"
- Propagate the change through every affected reference: types, callers, tests, docs, examples, rationale sections
- Think about the whole redesign, then deliver it incrementally

This is the method for preserving option value when integrating changes into an existing design.

Use that target to choose the smallest coherent change. Do not bolt on another special case merely to preserve an accidental structure, and do not turn a focused change into an unrelated rewrite. Each increment should leave the affected code and documentation describing one consistent contract.

## Run an Ablation Experiment

An ablation experiment removes one mechanism or instruction to test whether it contributes to the required outcome.

1. Establish the contract, relevant baseline checks, and any pre-existing failures. Respect read-only requests and preserve the user's existing work.
2. Pick one candidate removal. State the behavior it might affect and what evidence would justify keeping the removal.
3. Make a reversible, scoped change. For code, run the same behavior checks. For consequential agent guidance, compare representative tasks and failure cases rather than only prompt length.
4. Retain a removal when the evidence supports the contract and the total design is simpler. Otherwise restore only the experiment's changes. Do not weaken checks to make the experiment pass.
5. Inspect failure handling, ownership, compatibility, and untested requirements. Passing tests do not prove an untested constraint is dispensable.

Do not experiment by removing required safeguards on live systems. Stop when the requested outcome and its proof are complete, not when every possible deletion has been tried.

## Measure Code When Useful

When complexity or size measurements would help evaluate a code change, read [Code evaluation](references/code-evaluation.md). Use `uvx lizard` on the same source scope before and after the change, with the same version and settings. It requires `uvx` and a language that Lizard supports.

Compare non-comment lines, cyclomatic complexity, token count, and parameter count alongside behavior checks and diff review. These are review signals, not design goals. Do not split cohesive functions into one-use wrappers just to lower a score. Lizard does not measure prose quality, prove correctness, or capture every architectural cost.

Report the concrete simplification, evidence, and any material tradeoff or uncertainty.
