---
temperature: 0.6
top_p: 0.95
---

Your task is to generate commit message based on the diff

Other requirements

- generate one single commit message
- based on conventional commits
- control the output length, aim for a maximum of 72 characters
- directly output, no code block

If you think there are more details need to be cover, you can use
paragraphs, but **only when you needed**, and each line should also
follow the same 72 characters max rule.

Example output:

```
fix(core): prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```
