# Matt Pocock Skills Workflow

## Main Flow

```text
idea
  -> /grill-with-docs
  -> /to-spec
  -> /to-tickets
  -> /implement
  -> code-review
```

### Clarify the idea

Run `/grill-with-docs <idea>` to load `grilling` for the interview and
`domain-modeling` for terminology, `.opencode/CONTEXT.md`, and ADRs under
`.opencode/adr/`. Use
`/grill-me` when the interview should not update project documentation.

For work too large or uncertain for one session, run `/wayfinder <idea>`. It
creates a decision map and tickets under:

```text
.opencode/scratch/<effort>/map.md
.opencode/scratch/<effort>/issues/
```

Work one frontier ticket per session until the route is clear.

### Produce a spec

After the discussion, run `/to-spec`. It synthesizes the current conversation
without repeating the interview and writes:

```text
.opencode/scratch/<feature>/spec.md
```

Confirm the intended testing seams before publishing the spec.

Artifact-producing commands select the `build` agent explicitly. The default
`plan` agent remains read-only and is used for investigation and discussion.

### Split the work into tickets

Run:

```text
/to-tickets .opencode/scratch/<feature>/spec.md
```

Review the proposed tracer-bullet slices and blocking edges. After approval,
the command writes one file per ticket under:

```text
.opencode/scratch/<feature>/issues/
```

Tickets whose blockers are complete form the current frontier.

### Implement one ticket

Start a fresh session for each frontier ticket:

```text
/implement .opencode/scratch/<feature>/issues/01-<slug>.md
```

`/implement` loads `tdd` when the agreed seam supports it, implements and
validates the ticket, then loads `code-review`. It does not commit
automatically. Repeat for the next unblocked ticket.

## Supporting Commands

- `/handoff <description>` writes continuation context under `.opencode/handoffs/`.
- `/teach <topic>` creates a stateful workspace under `.opencode/teach/<topic>/`.
- `/writing-great-skills` guides creation and refinement of skills.

## Artifact Locations

| Artifact | Location |
| --- | --- |
| Domain glossary | `.opencode/CONTEXT.md` |
| Bounded-context glossaries | `.opencode/contexts/` |
| ADRs | `.opencode/adr/` |
| Specs, maps, and tickets | `.opencode/scratch/` |
| Saved plans | `.opencode/plans/` |
| Research reports | `.opencode/research/` |
| Prototypes | `.opencode/prototypes/` |
| Debugging artifacts | `.opencode/debug/` |
| Handoffs | `.opencode/handoffs/` |
| Teaching workspaces | `.opencode/teach/` |
| Saved BTW answers | `.opencode/btw/` |
| Skill feedback | `.opencode/papercut-<skill-name>/` |

Agent-owned working context is centralized here. Commit compact artifacts that
remain project evidence, such as ADRs, accepted specs, prototype source, and
learning records. Exclude generated previews/build output and delete disposable
debug or handoff artifacts when they are no longer useful. Production code,
tests, final fixes, and normal project documentation remain at their natural
project locations.

## Model-Invoked Skills

The model can load these when the task matches, or the user can request one
explicitly:

- `diagnosing-bugs`: hard bugs and performance regressions.
- `prototype`: state/logic experiments or UI alternatives under `.opencode/prototypes/`.
- `research`: background primary-source reports under `.opencode/research/`.
- `tdd`: red-green vertical slices.
- `domain-modeling`: terminology, `.opencode/CONTEXT.md`, and `.opencode/adr/` work.
- `codebase-design`: module interfaces and seams.
- `code-review`: independent Standards and Spec review axes.
- `grilling`: unresolved design decisions.

## Papercut Feedback

Skill friction is recorded at:

```text
.opencode/papercut-<skill-name>/<short-desc>-<timestamp>.md
```

Later, ask the model to review a skill's papercut directory and propose a
focused refinement, then delete resolved entries. In read-only mode, report the
papercut instead of writing it. Upstream update instructions live in
`docs/updating-matt-pocock-skills.md`.
