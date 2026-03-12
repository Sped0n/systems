---
urls:
  - https://httpie.io/docs/cli
---

# JSON Data

## Goals

- Keep JSON payloads concise for small requests.
- Preserve types when booleans, numbers, arrays, or objects matter.

## Guidance

- Use `name=value` for JSON string fields in inline requests.
- Use `name:=value` for raw JSON values such as booleans, numbers, arrays, and objects.
- Prefer a file or stdin for larger payloads instead of long shell-escaped objects.
- Do not mix JSON-style request items with `--form` unless the endpoint really expects multipart data.

## Examples

Simple JSON body with string fields:

```bash
http POST pie.dev/post name=Ada language=Rust
```

Typed JSON fields:

```bash
http POST pie.dev/post enabled:=true retries:=3 tags:='["cli", "http"]'
```

Nested object inline:

```bash
http POST pie.dev/post profile:='{"team":"core","active":true}'
```

Read JSON from a file via stdin:

```bash
http POST pie.dev/post Content-Type:application/json < payload.json
```

Pipe generated JSON into the request:

```bash
printf '{"name":"Ada","tags":["cli","http"]}\n' | http POST pie.dev/post Content-Type:application/json
```

See `references/forms-files.md` when the request should be form or multipart instead of JSON.
