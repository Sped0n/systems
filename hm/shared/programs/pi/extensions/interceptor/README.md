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

Append one strict policy after global and trusted-project rules for the lifetime
of a Pi process with an inline JSON CLI argument:

```bash
pi --interceptor-append-rules '{"rules":[{"bash":"git status*","action":"allow"}]}'
```

Extensions can append a scoped ordered rule group with
`appendInterceptorRules(policy, cwd)`. It returns an idempotent disposer that
removes only that group. Later runtime groups win over CLI rules, which win over
project and global rules. Reusable runtime policies live in `policies.ts`;
review and pcommit share its Git/rg inspection policy.

This is a tool-call interceptor, not an OS sandbox.
