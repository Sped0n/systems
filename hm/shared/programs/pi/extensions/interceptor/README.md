# Interceptor

Guards `read`, `edit`, `write`, and `bash` tool calls with deterministic ordered
rules from global `interceptor.json` and, for trusted projects,
`.pi/interceptor.json`. Global rules run first, project rules are appended, and
the last matching rule wins. Actions are `allow` and `deny`; unmatched inputs
default to `deny`. The extension never opens a dialog or creates an in-memory
approval, so behavior is identical in TUI, RPC, JSON, and print modes.

File rules use `path` and `operations`. Bash rules use `bash`; Bash patterns
support `*` and `?`, matching OpenCode's permission wildcards. Every rule may include a non-empty `reason` of at most 500 characters. A matching deny
returns that reason to the agent; allow rules ignore it. Bash is parsed with
tree-sitter, so chains, substitutions, process substitutions, and heredocs are
evaluated as syntax rather than split as text. Every executable command in a
compound input must be allowed.

An effective `{ "bash": "*", "action": "allow" }` rule with no later
restrictive rule bypasses parsing because it explicitly allows every command.
With narrower policies, invalid syntax and parser failures are denied so the
agent can correct the command.

```json
{
  "rules": [
    { "bash": "*", "action": "deny" },
    { "bash": "git *", "action": "allow" },
    { "bash": "git push*", "action": "deny" }
  ]
}
```

```json
{
  "rules": [
    { "bash": "*", "action": "allow" },
    {
      "bash": "pip",
      "action": "deny",
      "reason": "Use `uv pip` instead."
    },
    {
      "bash": "pip *",
      "action": "deny",
      "reason": "Use `uv pip` instead."
    }
  ]
}
```

Patterns match the complete parsed Bash command. `pip *` therefore denies
ordinary pip installs but do not match `uv pip install ...`. Bare commands need
separate `pip` rules. Alternative forms such as `python -m pip` also
need their own explicit rules.

Policy files are loaded when a session starts, including after `/reload`; they
are not read for each tool call. A successful load becomes the process-local,
last-valid policy for that working directory and trust state. If a later load
fails, the interceptor warns and keeps the matching last-valid policy. Without
a matching policy, it warns and uses an empty policy. Restarting Pi clears this
fallback cache.

Extensions can append a scoped ordered rule group with
`appendInterceptorRules(policy, cwd)`. It returns an idempotent disposer that
removes only that group. Runtime groups are evaluated after the loaded file
policy and remain dynamic between reloads. Later runtime groups win over earlier
ones. Reusable runtime policies live in `policies.ts`; review and pcommit share
its Git/rg inspection policy.

This is a tool-call interceptor, not an OS sandbox.
