---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---
<!-- Source: mattpocock/skills@391a2701dd948f94f56a39f7533f8eea9a859c87 skills/engineering/research/SKILL.md -->

Spin up an OpenCode `task` call using the `general` subagent to do the research, so you keep working while it reads. Use parallel task calls for independent research.

Its job:

1. Load `jina-cli` for web search and URL reading, and `librarian` when a remote Git repository is the primary source. Investigate against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Before dispatch, the parent allocates an exact unique path under `.opencode/research/` using a filesystem-safe lowercase description and UTC timestamp. Write the findings there, citing each claim's source.
3. Reuse an existing file only for a deliberate continuation of the same question; do not send parallel tasks to the same path. Say where the report was saved.
