---
name: web
description: >-
  Search and read web pages such as documentation, articles, issues, and pull
  requests. Route repository source or history inspection through librarian.
---

Use this skill for web research. It directly calls the Jina endpoints configured
by `JINA_READER_BASE` and `JINA_SEARCH_SVIP_BASE` with `JINA_API_KEY`;
`JINA_API_BASE` is available for general Jina API operations. The skill does not
require the Jina CLI.

```bash
node web.mjs search "OpenSCAD documentation" \
  --purpose "find authoritative API references"
node web.mjs read https://openscad.org/documentation.html
node web.mjs search "Nix flakes" --read --limit 3
node web.mjs search "Nix flakes" --read --out ./nix-research.md
```

`search` returns Jina Search results with source URLs. `read` returns Jina
Reader Markdown for a single HTTP(S) URL. `--read` retrieves the top search
results. Use `--json` for structured output.

Use `--out <file>` to save the normal text or JSON result instead of writing it
to stdout. The parent directory must already exist. The skill never invokes a
model; synthesize results in the calling Pi session when needed. When the user
wants a summary of long Reader output, save it with `--out` and apply the
`summarize` skill rather than loading and compressing it in the current session.
