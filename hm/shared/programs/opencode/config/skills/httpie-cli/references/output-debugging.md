---
urls:
  - https://httpie.io/docs/cli
---

# Output and Debugging

## Goals

- Show only the parts of the exchange that matter.
- Escalate from readable default output to full request and response inspection.

## Guidance

- Start with the default output for normal interactive use.
- Add `-v` when you need both request and response details.
- Use `--print=...` to select exact sections.
- Use `-h` for headers only and `-b` for body only.
- Follow redirects with `--follow`; add `--all` if you want the full redirect chain.

## Examples

Verbose request and response:

```bash
http -v pie.dev/get
```

Print request and response headers plus body:

```bash
http --print=HhBb pie.dev/get
```

Headers only:

```bash
http -h pie.dev/get
```

Body only:

```bash
http -b pie.dev/json
```

Follow redirects and show every hop:

```bash
http --follow --all pie.dev/redirect/2
```

See `references/headers-auth.md` for adding auth while debugging and `references/sessions-downloads.md` for persisted state.
