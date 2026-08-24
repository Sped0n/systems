# Pcommit

Implements the `--pcommit` and `--pcommit-hint` flags used by the Home Manager
`pcommit` wrapper. Pi runs headlessly with `--print --no-session`, switches that
single session to the `economy` tier, and activates only `read` and `bash`. A
scoped interceptor policy denies Bash by default and permits `git status`, `git
diff`, `git log`, `git show`, and `rg --no-config` while rejecting output
redirection and execution-capable flags.

The agent inspects staged changes, may read surrounding working-tree code, and
prints only a commit message describing staged changes. The wrapper captures
that message in an owner-only temporary file and runs:

```text
git commit --signoff --edit --file <message-file>
```

Git therefore opens the user's normal editor before creating the commit. The
wrapper removes the temporary file on every exit.

Usage:

```bash
pcommit
pcommit "focus on permission changes"
```

Pcommit requires staged changes, never stages files, and never pushes. While Pi
works, pcommit streams the current `read` or `bash` activity and the transition
to commit-message writing on stderr; stdout remains only the generated message.
Model, policy, or editor failures exit without committing. Runtime interceptor
rules are removed when the headless Pi session ends.
