# OpenAI Request Options

For GPT models using the Responses or Codex Responses API, request concise
reasoning summaries and low text verbosity. Reasoning effort and output formats
are preserved. Models and proxies must support these options.

`/fast` toggles `service_tier: "priority"` for subsequent requests, including
requests in an ongoing agent run. It does not interrupt an in-flight request.
Priority pricing may apply.

Fast mode defaults off and is saved per session branch. Resume restores it;
unsupported models suspend it without clearing the preference. The shared
[footer](../footer/README.md) highlights `(fast)` beside the model name while active.
