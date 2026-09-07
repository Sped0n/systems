# Name

Overrides Pi's interactive `/name` command with two forms:

- `/name <name>` immediately names or renames the current session.
- `/name` generates a concise name from the current branch's user and assistant
  text using the `economy` tier in `tiers.json`, then renames the session.

Generated-name input is bounded to 120 KB by retaining the beginning and end of
long conversations. Generated titles use the first non-empty output line and
are limited to 100 characters, matching OpenCode's title cleanup behavior.
Failures leave the existing session name unchanged and appear as an error
notification.
