---
urls:
  - https://httpie.io/docs/cli
---

# Basic Requests

## Goals

- Build the smallest correct request first.
- Keep method, URL, and request items readable at a glance.

## Guidance

- Use `http URL` for simple GET requests.
- Prefer an explicit method for mutating calls in examples and reviews.
- Use `name==value` for query string parameters.
- Use `name=value` for string fields and `name:=value` for raw JSON values.
- Treat request items as a quick separator map:
  - `Header:value` for headers
  - `name==value` for query params
  - `name=value` for string data
  - `name:=value` for typed JSON data

## Examples

Simple GET request:

```bash
http pie.dev/get
```

GET request with query parameters:

```bash
http pie.dev/get page==2 search==httpie
```

Explicit POST request with string fields:

```bash
http POST pie.dev/post name=Ada role=admin
```

PUT request with typed JSON values:

```bash
http PUT pie.dev/put id:=42 enabled:=true
```

DELETE request:

```bash
http DELETE pie.dev/delete
```

See `references/json-data.md` for deeper JSON payload patterns and `references/headers-auth.md` for headers.
