# Interceptor

Tool-call guard for `read`, `edit`, `write`, and `bash`; not an OS sandbox.

## Policy

- Sources: global `interceptor.json`, then trusted-project `.pi/interceptor.json`.
- Last matching rule wins. Actions: `allow`, `deny`. No match: deny.
- No approval dialogs or in-memory approvals; identical behavior in TUI, RPC, JSON, and print modes.
- File rules: `path`, `operations` (`read`, `write`), `action`.
- Bash rules: `bash`, `action`. Wildcards: `*`, `?`.
- Optional `reason`: non-empty string, at most 500 characters; ignored on allow rules.

```json
{
  "rules": [
    { "bash": "*", "action": "allow" },
    { "bash": "pip", "action": "deny", "reason": "Use `uv pip` instead." },
    { "bash": "pip *", "action": "deny", "reason": "Use `uv pip` instead." }
  ]
}
```

## Bash matching

- Patterns match complete parsed commands. `pip *` does not match bare `pip`, `uv pip install ...`, or `python -m pip ...`.
- Tree-sitter parses chains, substitutions, process substitutions, and heredocs. Every executable command must be allowed.
- An effective `{"bash":"*","action":"allow"}` with no later restrictive rule bypasses parsing.
- Otherwise, invalid syntax and parser failures are denied.

## Denial messages

- Prefix: `Interceptor denied the tool call: `.
- Matching deny: configured reason or match description, followed by `Matched rule: <JSON>`. JSON excludes `reason` and internal scope.
- No match or input/parser failure: explanation only.

## Reloading

- Policies load at session start and `/reload`, not per tool call.
- Successful loads populate a process-local last-valid cache keyed by working directory and trust state.
- Failed loads warn and retain the matching cached policy; without one, they use an empty policy.
- Restarting Pi clears the cache.
