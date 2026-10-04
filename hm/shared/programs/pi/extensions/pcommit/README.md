# Pcommit

Implements the `--pcommit` and `--pcommit-hint` flags used by the Home Manager
`pcommit` wrapper. Pi runs headlessly with `--print --no-session` using the
wrapper's configured provider, model, and thinking level, and activates only
`read`, `grep`, `find`, `ls`, and [`rogt`](../rogt/README.md). Git inspection uses
structured read-only operations; Bash is not active.

The agent inspects staged changes, may read surrounding working-tree code, and
prints only a commit message describing staged changes. The wrapper captures
that message in an owner-only temporary file and runs:

```text
git commit --signoff --edit --file <message-file>
```

The wrapper prints the generated message to stdout before invoking Git, so it
remains visible even if a commit hook fails. Git opens the user's normal editor
before creating the commit. The wrapper removes the temporary file on every exit.

The wrapper and extension are enabled by default with
`programs.my-pi.pcommit.enable`. Configure `programs.my-pi.pcommit.provider`,
`model`, and `thinking` to select the generation model; defaults are
`circe-responses`, `gpt-6.1-sol`, and `low`.

Usage:

```bash
pcommit
pcommit "focus on permission changes"
```

Pcommit requires staged changes, never stages files, and never pushes. While Pi
works, pcommit streams the current inspection-tool activity and the transition
to commit-message writing on stderr. The headless agent's stdout contains only
the generated message; the wrapper also allows Git's normal console output.
Model, inspection, or editor failures exit without committing.
