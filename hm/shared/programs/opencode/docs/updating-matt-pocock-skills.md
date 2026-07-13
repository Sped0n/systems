# Updating Matt Pocock Skills

This configuration vendors selected files from
[`mattpocock/skills`](https://github.com/mattpocock/skills). Keep the import close
to upstream so updates remain reviewable.

Current upstream commit:

```text
391a2701dd948f94f56a39f7533f8eea9a859c87
```

Every imported command has a `source` frontmatter field, and every imported
`SKILL.md` entrypoint has a `Source:` comment, containing its upstream commit and
path. OpenCode ignores the command field while keeping it out of the prompt.
Auxiliary files retain their upstream layout and are reviewed through the
directory comparison in the update procedure.

## Mapping

Model-invoked upstream skills remain OpenCode skills under `skills/`:

| Upstream skill | Local path |
| --- | --- |
| `engineering/prototype` | `skills/prototype/` |
| `engineering/diagnosing-bugs` | `skills/diagnosing-bugs/` |
| `engineering/research` | `skills/research/` |
| `engineering/tdd` | `skills/tdd/` |
| `engineering/domain-modeling` | `skills/domain-modeling/` |
| `engineering/codebase-design` | `skills/codebase-design/` |
| `engineering/code-review` | `skills/code-review/` |
| `productivity/grilling` | `skills/grilling/` |

User-invoked upstream skills become OpenCode commands under `commands/`:

| Upstream skill | Local command |
| --- | --- |
| `productivity/grill-me` | `commands/grill-me.md` |
| `engineering/grill-with-docs` | `commands/grill-with-docs.md` |
| `productivity/handoff` | `commands/handoff.md` |
| `productivity/teach` | `commands/teach.md` |
| `productivity/writing-great-skills` | `commands/writing-great-skills.md` |
| `engineering/wayfinder` | `commands/wayfinder.md` |
| `engineering/to-spec` | `commands/to-spec.md` |
| `engineering/to-tickets` | `commands/to-tickets.md` |
| `engineering/implement` | `commands/implement.md` |

## Porting Rules

Start from the complete upstream file. Do not summarize or rewrite sections.
Apply only these compatibility changes:

1. Remove `disable-model-invocation` from frontmatter. OpenCode commands provide
   the user-only invocation boundary.
2. For commands, remove `name` from frontmatter, keep `description`, and add
   `$ARGUMENTS` where the workflow accepts user input. Set `agent: build` on
   commands that write artifacts or implementation changes; keep discussion-only
   commands on the active agent.
3. Replace executable `/skill-name` calls with an explicit instruction to load
   and apply the corresponding model-invoked OpenCode skill. Do not rewrite
   ordinary prose that merely discusses skill invocation.
4. Replace Claude `Agent` or `general-purpose` subagent mechanics with OpenCode
   `task` calls using the `general` subagent. Preserve requested parallelism.
5. Use local Markdown under `.opencode/scratch/` as the issue tracker. Remove dependency
   on `setup-matt-pocock-skills` and `docs/agents/issue-tracker.md`, but preserve
   ticket templates, blocking semantics, frontier behavior, workflow steps, and
   the local atomic-claim convention documented in `wayfinder`.
6. Remove the instruction in `implement` that commits automatically. Commits
   remain user-authorized in this configuration.
7. Adapt `writing-great-skills` so user-invoked capabilities are OpenCode
   commands, not skills using `disable-model-invocation`. Keep its long-form
   reference in `skills/writing-great-skills/GLOSSARY.md` and keep the command
   body as the concise procedure and context pointer.
8. Preserve all other content, including rationale, completion criteria,
   examples, checklists, and auxiliary files.
9. Store the project domain glossary at `.opencode/CONTEXT.md`. For multiple
   bounded contexts, store child glossaries under `.opencode/contexts/`.
10. Keep generated agent artifacts under `.opencode/`: ADRs in `adr/`, research
    in `research/`, prototypes in `prototypes/`, debugging artifacts in
    `debug/`, handoffs in `handoffs/`, teaching workspaces in `teach/`, and
    specs/tickets/maps in `scratch/`. Production code, tests, and final fixes
    remain at their normal project locations.

Command directories are scanned recursively for Markdown files. Do not place
auxiliary `.md` files under `commands/`: OpenCode would expose them as commands.
Inline command-owned templates into the command body, or keep references in a
model-invoked skill that owns them. Non-Markdown auxiliary files are safe.

## Update Procedure

1. Load the `librarian` skill and refresh the upstream checkout:

   ```bash
   bash ~/.config/opencode/skills/librarian/checkout.sh \
     mattpocock/skills --force-update --path-only
   ```

2. Record the new upstream commit:

   ```bash
   git -C ~/.cache/checkouts/github.com/mattpocock/skills rev-parse HEAD
   ```

3. Read the upstream changelog between the old and new commits. Check for
   renamed, deleted, or newly required skills before copying files.
4. Compare each mapped upstream directory with its local destination. Copy the
   complete new upstream content, then reapply only the porting rules above.
5. Update every command `source` field, every skill `Source:` comment, and the
   current commit in this document.
6. Search active projects for relevant
   `.opencode/papercut-<skill-name>/` directories. Apply a papercut only when it
   remains valid against the new upstream version; do not fold project-specific
   bugs into a global skill.
7. Review the final diff against both old local content and new upstream
   content. Large unexplained deletions usually mean the import was summarized
   accidentally.

Useful comparisons:

```bash
git -C ~/.cache/checkouts/github.com/mattpocock/skills \
  diff <old-commit>..<new-commit> -- skills/engineering skills/productivity

git diff -- hm/shared/programs/opencode/config/skills \
  hm/shared/programs/opencode/config/commands
```

## Validation

Run at least:

```bash
git diff --check
nix flake check -L --keep-going
oc debug config
oc debug skill
nix run nixpkgs#bun -- build hm/shared/programs/opencode/config/plugins/btw.tsx \
  hm/shared/programs/opencode/config/plugins/save-md.tsx --target=bun \
  --external '@opencode-ai/*' --external '@opentui/*' --external solid-js \
  --outdir "${TMPDIR:-/tmp}/opencode-plugin-build"
```

Confirm that `oc debug skill` lists every model-invoked skill in the mapping.
After applying Home Manager and restarting OpenCode, confirm every command in
the mapping appears in slash-command completion. Also exercise `/btw` and
`/save-md`; experimental Markdown rendering and TUI plugin APIs are part of the
OpenCode update compatibility check.

When upstream adds a dependency on another skill, either import that dependency
using the same invocation classification or adapt the reference explicitly.
Never leave a command pointing at an unavailable skill or setup workflow.

## Efficient Update Path

Keep updates reviewable rather than making the vendored tree a blind mirror.
Local command frontmatter, artifact paths, tracker operations, and OpenCode task
mechanics are intentional overlays that upstream cannot generate correctly.

For each update:

1. Refresh the cached checkout once and pin the candidate commit before editing.
2. Use the mapping table as the work queue. Compare and update one mapped
   capability at a time, including its auxiliary files, then reapply only the
   porting rules above.
3. Separate upstream changes from local porting decisions in the review: first
   inspect `git diff <old>..<new> -- <upstream-path>`, then inspect the local
   destination diff. This makes accidental summaries and lost local adaptations
   obvious.
4. Run validation once after all mappings are complete, not after each copy.

If this is repeated often enough to automate, add one small script driven by a
machine-readable version of the mapping table. It should fetch, stage upstream
files in a temporary directory, and print per-mapping diffs; it should not
overwrite live files or attempt semantic prompt merges. Human reapplication of
the short porting-rule list is the safety boundary.
