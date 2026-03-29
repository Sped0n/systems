---
urls:
  - https://httpie.io/docs/cli
---

# Sessions and Downloads

## Goals

- Reuse cookies and auth across related requests.
- Save large responses without losing readable command structure.

## Guidance

- Use `--session=FILE` to persist cookies and other session state between commands.
- Keep session files local to the task or project when the state matters.
- Use `--download` for binary or large file responses.
- Add `--output FILE` to control the destination path.
- Use `--continue` to resume an interrupted download when the server supports it.

## Examples

Create a reusable session while receiving cookies:

```bash
http --session=login.json pie.dev/cookies/set/sessionid/abc123
```

Reuse the same session on a later request:

```bash
http --session=login.json pie.dev/cookies
```

Download a file to a chosen path:

```bash
http --download --output artifact.tar.gz https://example.com/artifact.tar.gz
```

Resume a partial download:

```bash
http --continue --download --output artifact.tar.gz https://example.com/artifact.tar.gz
```

See `references/output-debugging.md` when you need to inspect headers around redirects, caching, or cookies.
