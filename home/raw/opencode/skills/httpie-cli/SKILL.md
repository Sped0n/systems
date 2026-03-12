---
name: httpie-cli
description: Practical guidance for making HTTP requests with HTTPie from the command line. Use when testing APIs, sending JSON or forms, inspecting responses, or working with auth, sessions, and downloads.
---

# httpie-cli

Concise guidance for composing readable HTTP requests with HTTPie while keeping request intent obvious.

## Purpose and Triggers

- Use when making ad hoc HTTP requests, testing APIs, or showing CLI examples.
- Reach for HTTPie when readable request items are better than dense `curl` flags.
- Covers JSON, forms, files, auth, sessions, downloads, and response inspection.

## Decision Order

1. Pick method and URL.
2. Choose query, JSON, form, or file request items.
3. Add headers and auth.
4. Decide how much output and persistence you need.

## Workflow

1. Start with the smallest working request.
2. Add request items one concern at a time.
3. Open the matching reference for deeper syntax or flags.

## Topics

| Topic               | Guidance                                                | Reference                                                            |
| ------------------- | ------------------------------------------------------- | -------------------------------------------------------------------- |
| Basic Requests      | Methods, URLs, query params, and request item basics    | [references/basic-requests.md](references/basic-requests.md)         |
| Headers and Auth    | Custom headers, API tokens, and basic auth              | [references/headers-auth.md](references/headers-auth.md)             |
| JSON Data           | String fields, typed values, raw JSON, and stdin input  | [references/json-data.md](references/json-data.md)                   |
| Forms and Files     | Form submissions, multipart bodies, and uploads         | [references/forms-files.md](references/forms-files.md)               |
| Output and Debugging | Response inspection, redirects, and print modes        | [references/output-debugging.md](references/output-debugging.md)     |
| Sessions and Files  | Cookie persistence, reusable sessions, downloads        | [references/sessions-downloads.md](references/sessions-downloads.md) |
| Advanced Usage      | Offline mode, status handling, and shell-friendly flows | [references/advanced-usage.md](references/advanced-usage.md)         |

## References

- Each topic file lists source URLs in its frontmatter `urls`.
- Official docs: https://httpie.io/docs/cli
