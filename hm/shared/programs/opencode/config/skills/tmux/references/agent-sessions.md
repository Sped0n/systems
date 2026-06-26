---
urls:
  - https://github.com/tmux/tmux/wiki
---

# Agent Sessions

## Policy

- Tmux can host agent-owned worker shells or other long-running agent CLIs.
- Do not spawn autonomous coding agents in the same worktree unless the user explicitly asks or the task clearly needs parallel long-running work.
- Prefer opencode's built-in Task tool for normal subagent research and code exploration.
- If a tmux-hosted worker may edit files, assign non-overlapping scope and state it before starting.
- Never run two writer agents against the same files without explicit user approval.

## Naming

- Use the private opencode socket.
- Use session names that include role and purpose: `opencode-worker-docs`, `opencode-monitor-tab5`, `opencode-repro-crash`.
- Use one session per worker/purpose.

## Reporting

- Immediately report the session name and monitor command after starting a long-running worker.
- Capture bounded output before making decisions based on worker progress.
- Kill workers when done unless the user asked to keep them running.

## Safety

- Avoid hidden background edits.
- Avoid shell history or environment changes that affect the user's session.
- Keep logs and outputs discoverable through tmux capture commands.
