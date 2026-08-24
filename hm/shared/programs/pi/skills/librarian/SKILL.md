---
name: librarian
description: Cache and inspect remote Git repositories locally. Use first for GitHub, GitLab, or other repository URLs, owner/repo references, source trees, branches, and history.
metadata:
  source: "https://github.com/mitsuhiko/agent-stuff"
  commit: "13bc8f87970bec8830aab0f1c0487d35aa7c0917"
---

Use this skill when a user provides a remote Git repository or it is discovered while researching.

Run:

```bash
bash checkout.sh <repo> --path-only
```

Supported inputs include `owner/repo`, hosted URLs, `git@host:org/repo.git`, and `ssh://` URLs. SSH transport, credentials, and custom ports are retained. For example, `ssh://git@gitlab.example:27227/org/repo.git` is cloned and refreshed through that SSH URL.

The cache is stable, uses partial clones, refreshes at most every five minutes by default, and fast-forwards only clean checkouts. Override the cache root with `LIBRARIAN_CACHE_ROOT`, force a refresh with `--force-update`, or configure the interval with `--update-interval <seconds>`.

For `--path-only`, an existing cache whose remote explicitly reports that the repository no longer exists is still returned. The script emits a `LIBRARIAN_STALE` warning on stderr; inspect the checkout before relying on it. Authentication, network, and other fetch failures remain errors.

Do not edit the shared cache. Create a separate worktree or copy for task-specific changes.
