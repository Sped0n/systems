---
name: writing-for-agents
description: Write or revise agent instructions, including skills, AGENTS.md, and CLAUDE.md.
metadata:
  source: "https://github.com/mattpocock/skills"
  commit: "9c9f36ccd3995266cd675468af71639c8dde1ec5"
---

# Writing for agents

Write task-specific guidance that helps an agent choose the right action and recognize completion. Preserve precise meaning over token count.

When creating or changing a skill, read [Skill mechanics](SKILL-MECHANICS.md) for Pi frontmatter, discovery, and reference loading.

## Scope and routing

- State what the document governs and when it applies. Use concrete task triggers rather than broad claims of usefulness.
- Keep descriptions and always-loaded instructions short. Distinguish genuinely different triggers; collapse synonyms for the same case.
- Keep the common workflow and essential guardrails in the entry document. Move branch-specific procedures and examples into references only when that reduces what an unrelated task must read.
- Give each reference a path and an explicit condition for reading it. Keep rules, caveats, and examples for the same concept together.
- Split a skill only when the new skill needs an independent trigger. Shared reference alone does not require another skill.

## Instructions and completion

- Use direct language, concrete actions, and observable completion criteria. Explain ordering where a later action depends on an earlier result.
- Match the required investigation and proof to the task's scope and risk. Avoid universal exhaustiveness requirements for small edits.
- State authorization, read-only boundaries, destructive-operation approval, and rollback requirements wherever they govern the workflow. A reference is not permission to perform its actions.
- Prefer positive instructions where clear; retain explicit prohibitions when they communicate a real boundary.
- Keep distinct requirements distinct. A vague adjective is not a substitute for separate constraints such as determinism, latency, and resource use.

## Authority and maintenance

- Give each rule one authoritative home and link to it elsewhere. Avoid copying shared policy into every skill.
- Point to discoverable configuration, scripts, or help output instead of duplicating facts that change there. Document non-obvious conventions, rationale, and lookup pitfalls.
- Remove stale guidance and unrelated doctrine. Prefer the smallest useful instruction over a glossary or theory of model behavior.
- Treat claims about prompting effectiveness as model-relative hypotheses. When pruning consequential guidance, compare representative task runs and check failures, not just length.
- Do not remove safety or authorization constraints merely because a model usually follows them without prompting.

## Review

Check that triggers match the intended tasks, referenced files exist, and each branch exposes its prerequisites and completion proof. For simple Markdown changes, inspect the diff; for commands or harness-specific mechanics, verify against current documentation or a narrow executable check.
