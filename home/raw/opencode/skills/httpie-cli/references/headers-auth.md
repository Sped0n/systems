---
urls:
  - https://httpie.io/docs/cli
---

# Headers and Auth

## Goals

- Make authentication explicit and easy to audit.
- Keep custom headers readable without losing shell safety.

## Guidance

- Use `Header:value` request items for one-off headers.
- Prefer explicit `Authorization:` headers for bearer or API-key style tokens.
- Use `-a user:pass` for basic auth when the endpoint expects it.
- Keep secrets in environment variables instead of shell history when possible.

## Examples

Custom request headers:

```bash
http pie.dev/headers Accept:application/json X-Trace-Id:abc123
```

Bearer token via header:

```bash
http pie.dev/get Authorization:"Bearer $TOKEN"
```

API key header:

```bash
http pie.dev/get X-API-Key:$API_KEY
```

Basic auth:

```bash
http -a alice:s3cr3t pie.dev/basic-auth/alice/s3cr3t
```

Combine auth and data:

```bash
http POST pie.dev/post Authorization:"Bearer $TOKEN" name=Ada
```

See `references/output-debugging.md` when you need to inspect the full request and response.
