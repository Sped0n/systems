---
name: hunk
description: Load the installed Hunk CLI's instructions for reviewing diffs in a live Hunk session.
disable-model-invocation: true
---

Run `hunk skill show` to load the review instructions bundled with the installed Hunk CLI. If loading the instructions as a file instead, run `hunk skill path` and read the file at the returned path. Use one method, not both.

Follow the bundled instructions for the user's requested review task. If `hunk` is not available on `PATH`, report that and stop.
