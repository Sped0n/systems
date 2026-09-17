# Context management

Observational compaction, lossless session recall, stateless tool-result masking,
and transient context-pressure guidance. Pi's native session is the only durable
source: the extension creates disposable views and stores no sidecars, indices,
ledgers, or external memory.

## Memory model

```text
                         ┌─ observer view ─> bounded Markdown observation
native session entries ─┼─ context view  ─> consumed large results masked
                         └─ recall view   ─> search and exact entry reads
                              │
                       native session entry IDs
```

Pi continues to own compaction thresholds, cut points, retained tails, session
persistence, branching, events, and token accounting. Original entries are
never rewritten or deleted.

### Shared trace view

`view.ts` lowers native entries into chronological, role-aware blocks identified
by native entry ID. It preserves user text, assistant conclusions, concise tool
calls, errors, and tool results; strips `write` and `edit` payload bodies;
represents images as metadata; and excludes recall echoes, hidden shell output,
and private custom state.

Observer rendering bounds successful tool-result excerpts and supplies exact
entry pointers. If the whole input is too large, it keeps deterministic head and
tail regions with an omitted-entry-range marker. It does not assign semantic
priority or decide which natural-language state is active.

### Evolving observation

Every automatic, overflow, or manual `/compact [focus]` compaction gives the
observer:

- the previous observation;
- the newly compacted trace;
- Pi's retained-tail trace;
- optional manual focus instructions.

The selected model rewrites these into bounded Markdown:

```markdown
## Current task

## Active context

## Observations

## Open work

## Suggested next action
```

The observer preserves applicable constraints and decisions, incorporates newer
corrections, merges repetition, removes stale procedural detail, and retains
useful outcomes, blockers, paths, commands, errors, identifiers, and entry IDs.
Output is limited to 8,192 tokens. The request is tool-free, uses no prompt-cache
retention, and has a separate routing session ID.

Only a non-empty response with a normal `stop` commits. Provider errors,
cancellation, tool calls, output-length termination, empty output, and stale
session or branch state commit nothing. There is deliberately no fallback to
Pi's native summarizer, so every compaction route has one memory format.

Compaction details retain only `compactor: "ctx"` and Pi-compatible read/modified
file lists. Observation history and original evidence remain in native session
entries.

## Tools

### `compact({})`

Call `compact` alone in its tool batch at a coherent boundary. It terminates the
current tool run, waits for settlement, performs the same observational
compaction used automatically, and continues exactly once after success. It
cancels cleanly on failure, abort, shutdown, or branch change.

### `recall({ action, target, offset, scope })`

Search or read the current native session, including entries hidden by
compaction:

```text
recall({ action: "search", target: "auth token", offset: 0, scope: "lineage" })
recall({ action: "read", target: "a1b2c3d4", offset: 0, scope: "lineage" })
```

Search uses case-insensitive literal OR terms, ranks rarer terms before common
ones and newer entries on ties, and returns up to five role-labelled snippets
with exact read arguments. Empty search lists recent entries. Read returns up to
12,000 UTF-16 characters and supplies continuation arguments. `lineage` follows
the active branch; `all` includes every branch in this session, never other
session files. `/recall [request]` queues agent-led recovery.

## Disposable provider context

### Tool-result masking

On each context build, `view.ts` masks a tool result only when:

- its exact native entry is present in provider context;
- its text exceeds 8,000 characters; and
- a later assistant entry has consumed it.

The replacement contains the tool name and an exact-entry `recall(read, ...)`
pointer. Results after the latest assistant remain unchanged. Reused provider
call IDs cannot select another entry, and stored history is never mutated. No
projection metadata is persisted.

### Context pressure

`pressure.ts` is pure and calculates usage against Pi's pre-compaction budget:

```text
budget = context window - reserve tokens
ratio  = used tokens / budget
```

When `compact` is active, `index.ts` appends one transient, undisplayed provider
annotation at the highest current level:

| Usage | Level    | Guidance                                                                |
| ----: | -------- | ----------------------------------------------------------------------- |
|   60% | advisory | Do not compact solely due to pressure; plan toward a coherent boundary. |
|   75% | high     | Compact at the next coherent boundary if substantial work remains.      |
|   90% | critical | Compact now unless finishing immediately.                               |

The annotation includes actual used, budget, and remaining token estimates plus
the percentage used. It is recalculated for every request, never added to
session history, and disappears automatically when pressure falls.

## Validation

From `hm/shared/programs/pi`:

```bash
pnpm run check
node --import tsx --test extensions/ctx/test.ts
```
