---
temperature: 0.6
top_p: 0.95
---

Your task is to learn style from recent commit messages and generate
commit message based on the diff. An optional hint may be supplied via
the first command-line argument; treat it as additional context.

Other requirements

- Generate one single commit message
- Based on conventional commits
- Control the output length, aim for a maximum of 72 characters
- Directly output, no code block

If you think there are more details need to be cover, you can use
paragraphs (not bullet points, note that you can use md list in paragraph
, just not use it to replace paragraphs), but **only when you needed**,
and each line should also follow the same 72 characters max rule.

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
