# Interceptor

Tool-call guard for `read`, `edit`, `write`, and `bash`; not an OS sandbox. File rules do not restrict filesystem access inside Bash commands.

## Policy

- Sources: global `interceptor.json`, then trusted-project `.pi/interceptor.json`.
- The last matching permission rule wins. Actions are `allow`, `deny`, and `remind`. No permission match denies the call. Reminders never grant access or override a denial.
- No approval dialogs or in-memory approvals; identical behavior in TUI, RPC, JSON, and print modes.
- Each rule requires a non-empty `matches` list. Any matching entry makes the rule apply. Each entry contains either `path` and `operations` (`read`, `write`), or `bash`.
- `message` is required for `remind`, optional for `deny`, and invalid for `allow`. It must be a non-blank string of at most 500 characters. Unknown fields are rejected.

```json
{
  "rules": [
    { "matches": [{ "bash": "*" }], "action": "allow" },
    {
      "matches": [{ "bash": "pip" }, { "bash": "pip *" }],
      "action": "deny",
      "message": "Use `uv pip` instead."
    },
    {
      "id": "tmp-usage",
      "matches": [
        { "path": "/tmp/**", "operations": ["write"] },
        { "bash": "*/tmp/*" }
      ],
      "action": "remind",
      "message": "Keep temporary files small and short-lived.",
      "once": true
    }
  ]
}
```

## Path matching

- The read tool uses `read`. The edit and write tools use `write`. Paths match exactly or use a terminal `/**` to include the root and its descendants.
- Allow rules check resolved paths. Deny rules check both original and resolved paths to protect sensitive symlink aliases.
- `$CWD` refers to the policy's working directory, and `~` refers to the home directory. Both support a `/...` suffix.
- `${VAR}` expands from Pi's process environment in path matchers when the policy loads. Missing or empty variables silently skip the affected matcher.
- Expansion happens once, without shell execution or fallback expressions. Variable values cannot introduce globs or further `${...}` expressions. Bash patterns, messages, and tool inputs stay literal. Variables set inside a shell command are not available to the interceptor.

## Bash matching

- Patterns match complete parsed commands. `pip *` does not match bare `pip`, `uv pip install ...`, or `python -m pip ...`. Wildcards are `*` and `?`.
- Tree-sitter parses chains, substitutions, process substitutions, and heredocs. Every executable command must be allowed.
- A catch-all Bash allow with no later Bash deny bypasses permission parsing. Reminder rules do not change this behavior.
- Otherwise, invalid syntax and parser failures are denied.

## Reminders

- A `remind` rule requires a stable `id`, unique within its file. Global and project IDs are independent. Other actions do not accept `id` or `once`.
- `once` defaults to `true`. All matchers share one delivery per context window, including concurrent calls. Successful compaction allows delivery on the next match. Failed or cancelled compaction changes nothing. With `once: false`, every matching allowed call sends a reminder.
- Pi restores delivery history from reminder messages in the active session branch. Reloading and resuming preserve it. A new session starts fresh. Changing an ID creates a new reminder identity.
- Reminders enter the model's context without appearing in the TUI. The model receives them on its next request. Delivery does not force another turn, retry the command, or skip other calls. The tool still runs, so the reminder cannot change the current command.
- Path reminders check original and resolved paths. Bash reminders check the whole source and each parsed command. They match text, not filesystem effects. Patterns may match read-only commands and miss paths supplied through variables or scripts.
- Reminder failures warn without denying an allowed operation.

## Denial messages

- Prefix: `Interceptor denied the tool call: `.
- Matching deny: configured `message` or match description, followed by `Matched rule: <JSON>`. JSON excludes `message` and internal scope and source fields.
- No match or input/parser failure: explanation only.

## Reloading

- At process startup, configuration failures go to stderr before the TUI starts. This check may read project policy data but does not activate it or grant trust.
- Policies load at session start and `/reload`, not per tool call.
- Successful loads populate a process-local last-valid cache keyed by global configuration directory, working directory, and trust state.
- Failed loads warn and retain the matching cached policy; without one, they use an empty policy and deny guarded calls. Warnings appear in the TUI, or on stderr in non-interactive modes.
- Restarting Pi clears the cache.
- Environment changes require a reload. Pi reads its own process environment, not later changes in another shell.
