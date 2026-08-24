---
name: document
description: Convert a URL or local document to Markdown with markitdown.
metadata:
  source: "https://github.com/mitsuhiko/agent-stuff"
  commit: "13bc8f87970bec8830aab0f1c0487d35aa7c0917"
---

Use this skill to convert URLs, PDFs, Office documents, HTML, and text files
into Markdown for inspection.

```bash
node to-markdown.mjs <url-or-path> [--out <file>|--tmp]
```

Conversion uses `uvx --from 'markitdown[pdf]' markitdown`. Without an output
option, Markdown is written to stdout. `--out` writes a named file; `--tmp`
writes a temporary file and prints its path. When the user wants a summary of a
long document, convert it with `--tmp` or `--out`, then apply the `summarize`
skill to the resulting Markdown path.
