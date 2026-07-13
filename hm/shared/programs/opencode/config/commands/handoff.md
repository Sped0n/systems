---
description: Compact the current conversation into a handoff document for another agent to pick up.
agent: build
source: mattpocock/skills@391a2701dd948f94f56a39f7533f8eea9a859c87 skills/productivity/handoff/SKILL.md
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it under `.opencode/handoffs/<short-desc>-<timestamp>.md`, using a filesystem-safe lowercase description and UTC timestamp `YYYYMMDDTHHMMSSZ`.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

$ARGUMENTS
