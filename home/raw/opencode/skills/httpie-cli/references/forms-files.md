---
urls:
  - https://httpie.io/docs/cli
---

# Forms and Files

## Goals

- Switch cleanly between JSON and form-style requests.
- Make multipart uploads obvious in command examples.

## Guidance

- Use `--form` when the endpoint expects form fields or multipart bodies.
- With `--form`, `name=value` becomes a form field instead of a JSON string field.
- Use `field@path` for file uploads.
- Add `;type=mime/type` when the server cares about the uploaded content type.

## Examples

Simple form submission:

```bash
http --form POST pie.dev/post name=Ada role=admin
```

Multipart upload with one file:

```bash
http --form POST pie.dev/post avatar@./avatar.png
```

Multipart upload with fields and a file:

```bash
http --form POST pie.dev/post title=report doc@./report.pdf
```

Upload with an explicit MIME type:

```bash
http --form POST pie.dev/post note=release-notes 'changelog@./CHANGELOG.md;type=text/markdown'
```

See `references/json-data.md` for the JSON-first path and `references/headers-auth.md` for auth on upload requests.
