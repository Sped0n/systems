---
name: summarize
description: >-
  Summarize long web pages, converted documents, Markdown files, or supplied
  text in an isolated economy-model Pi process. Use when the user asks for a
  summary or wants source material compressed without filling the current
  session context.
---

# Summarize

Acquire source material as Markdown, then compress it in an isolated Pi process.

1. For a web page, apply the `web` skill and save Reader output with `--out`.
2. For a local PDF, Office file, HTML file, or other document, apply the
   `document` skill and use `--tmp` or `--out`.
3. For existing Markdown, use the file directly. For supplied raw text, write
   it to a temporary Markdown file.
4. Run:

```bash
node summarize.mjs <markdown-path> [focus instructions]
```

The script selects the economy tier from `tiers.json`, disables tools,
extensions, skills, templates, and context files in the child, and prints only
the child summary. Return that summary to the user.

Keep acquisition and summarization separate: `web` and `document` own faithful
conversion; this skill owns lossy compression. Do not build another combined
fetch/convert/summarize path.
