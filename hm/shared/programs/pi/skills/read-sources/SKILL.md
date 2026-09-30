---
name: read-sources
description: >-
  Search the web, read web pages, and convert local files or document URLs
  such as PDFs and Office documents to Markdown for inspection.
---

Choose the tool by task:

- Search or read web pages: use `web.py` (Jina).
- Convert local files or document URLs to Markdown: use `to-markdown.py`
  (MarkItDown).

Resolve script paths relative to this skill directory. Neither script invokes
a model; synthesize results in the current session.

## Search and read web pages

```bash
python3 web.py search "OpenSCAD documentation" \
  --purpose "find authoritative API references"
python3 web.py read https://openscad.org/documentation.html
python3 web.py search "Nix flakes" --read --limit 3
python3 web.py search "Nix flakes" --read --out ./nix-research.md
```

`search` returns Jina Search results with source URLs. `read` returns Jina
Reader Markdown for a single HTTP(S) URL. `--read` retrieves the top search
results. Use `--json` for structured output.

The script calls the endpoints configured by `JINA_READER_BASE` and
`JINA_SEARCH_SVIP_BASE` with `JINA_API_KEY`; it does not require the Jina CLI.

Use `--out <file>` to save the text or JSON result instead of writing it to
stdout. For long pages, save with `--out` and read the resulting file in focused
portions.

## Convert documents

```bash
python3 to-markdown.py <url-or-path> [--out <file>|--tmp]
```

Conversion uses `uvx --from 'markitdown[pdf]' markitdown` for PDFs, Office
documents, HTML, and text files. Without an output option, Markdown is written
to stdout. `--out` writes a named file; `--tmp` writes a temporary file and prints
its path. For long documents, convert with `--tmp` or `--out`, then read the
resulting Markdown in focused portions.

For both scripts, the parent directory of an `--out` file must already exist.
