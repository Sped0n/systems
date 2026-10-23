---
name: handoff
description: Summarize the current conversation in a handoff document so another agent can continue the work.
disable-model-invocation: true
metadata:
  source: "https://github.com/mattpocock/skills"
  commit: "5beb35b040e3de97e54fa9e386d7e42d15c295c2"
  adaptation: "Pi-native skill references and temporary-file workflow."
---

# Handoff

Write a concise handoff document so a fresh agent can continue the work. If the user supplied arguments, use them to focus the handoff on the next session.

Include the goal, active constraints and authorization boundaries, decisions, current state, validation results, and next steps. Distinguish verified facts from assumptions and unresolved questions.

Reference existing specs, plans, ADRs, issues, commits, and diffs by path or URL instead of duplicating their contents. Use absolute paths for local files so they can be found from another working directory.

Include a suggested skills section with each relevant skill's name, `SKILL.md` path, and when to read it. The next agent loads skills with `read`; the user can explicitly load one with `/skill:name`.

Redact secrets and sensitive personal information.

Save to a uniquely named Markdown file in the OS temporary directory (`$TMPDIR`, else `/tmp`; `%TEMP%` on Windows), not the workspace. Report the saved path.
