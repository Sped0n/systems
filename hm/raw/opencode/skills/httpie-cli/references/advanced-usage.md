---
urls:
  - https://httpie.io/docs/cli
---

# Advanced Usage

## Goals

- Keep complex requests inspectable before they hit the network.
- Fit HTTPie cleanly into larger shell workflows.

## Guidance

- Use `--offline` to render the request without sending it.
- Use `--check-status` in scripts so HTTP failures become shell-visible failures.
- Prefer files, stdin, and environment variables over huge inline shell strings.
- Pipe response bodies into other tools when you need post-processing.

## Examples

Preview a request without sending it:

```bash
http --offline POST api.example.test/users name=Ada admin:=false
```

Fail fast in shell automation on HTTP errors:

```bash
http --check-status pie.dev/status/404
```

Pipe a response into `jq`:

```bash
http GET pie.dev/get page==1 | jq '.args'
```

Generate part of the request from environment variables:

```bash
http POST pie.dev/post Authorization:"Bearer $TOKEN" env=$DEPLOY_ENV version=$APP_VERSION
```

See `references/basic-requests.md` for request item syntax and `references/json-data.md` for larger JSON bodies.
