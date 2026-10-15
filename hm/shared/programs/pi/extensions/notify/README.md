# Notify

- Trigger: `agent_settled` while unfocused; aborted runs and noninteractive modes excluded.
- Focus: stdin focus reports; focused by default. Inactive tmux panes and windows count as unfocused.
- Content: project directory name and “Waiting for input”.
- Delivery: OSC 777, with passthrough for one tmux layer; no external notifier or replay.

## Requirements

- Ghostty: `desktop-notifications = true` (default).
- OS: notifications permitted.
- tmux: attached client, `focus-events on`, and `allow-passthrough all`.
  Passthrough applies to all terminal escape sequences from hidden panes, not only notifications.
