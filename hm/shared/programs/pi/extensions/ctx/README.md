# Context management

This extension adds observational compaction, session recall, tool-result masking,
and context-pressure guidance. Pi's native session remains the only durable
source. The extension creates temporary provider views and stores no sidecars,
indices, or external memory.

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

`view.ts` converts native entries into chronological, role-aware blocks. Each
block has its native entry ID and timestamp. The view preserves user text,
assistant conclusions, concise tool calls, errors, and tool results. It removes
`write` and `edit` payload bodies, represents images as metadata, and excludes
recall echoes, hidden shell output, and private custom state.

Observer rendering clips large successful tool results and provides exact entry
pointers. If the input exceeds its budget, it keeps deterministic head and tail
regions with a marker for the omitted entry range. It does not rank facts or
decide which natural-language state is current.

### Evolving observation

Every automatic, overflow, or manual `/compact [focus]` compaction gives the
observer:

- a bounded trace of genuine user directives from the newly compacted span;
- the previous observation;
- the newly compacted general trace;
- Pi's retained-tail trace;
- optional focus instructions from manual compaction.

The selected model rewrites these into bounded Markdown:

```markdown
## Current task

## Active user directives

## Accepted decisions

## Current state

## Open work

## Suggested next action
```

The separate user trace keeps tool-heavy spans from displacing user requirements
and corrections. A directive remains active until a later genuine user message
supersedes it. A task phase change does not revoke it. Important directives,
decisions, and time-sensitive state retain timestamps and native entry IDs for
exact recall.

The output limit is 8,192 tokens. The observer has no tools, does not retain a
prompt cache, and uses a separate routing session ID.

The extension commits only a non-empty response with a normal `stop`. Provider
errors, cancellation, tool calls, output-length termination, empty output, or a
stale session or branch cancel the compaction. It does not fall back to Pi's
native summarizer, so every compaction route has one memory format.

Compaction details retain only `compactor: "ctx"` and Pi-compatible read/modified
file lists. Observation history and original evidence remain in native session
entries.

## Tools

### `compact({})`

Call `compact` alone in its tool batch at a coherent boundary. It ends the
current tool run, waits for settlement, runs the same observation used by
automatic compaction, and continues once after success through a hidden custom
message. The message enters model context without counting as user intent.
Failure, abort, shutdown, or a branch change cancels compaction without changing
history.

### `recall({ action, target, offset, scope })`

Search or read the current native session, including entries hidden by
compaction:

```text
recall({ action: "search", target: "auth token", offset: 0, scope: "lineage" })
recall({ action: "read", target: "a1b2c3d4", offset: 0, scope: "lineage" })
```

Search uses case-insensitive literal OR terms and returns up to five snippets of
600 characters. It ranks rarer terms first and uses recency to break ties. Empty
search lists recent entries. Read returns up to 12,000 UTF-16 characters and
provides continuation arguments. Both results include native timestamps.
`lineage` follows the active branch. `all` includes every branch in this session,
but never another session file. `/recall [request]` queues agent-led recovery.

## Disposable provider context

### Tool-result masking

On each context build, `view.ts` masks a tool result only when:

- its exact native entry is present in provider context;
- its text exceeds 8,000 characters; and
- a later assistant entry has consumed it.

The replacement contains the tool name and an exact-entry `recall(read, ...)`
pointer. Results after the latest assistant remain unchanged. The extension
matches provider messages to native entries by timestamp, tool-call ID, tool
name, and occurrence. This works with Pi's cloned context messages and prevents
a reused provider call ID from selecting another entry. The extension does not
mutate stored history or persist projection metadata.

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

The annotation includes used, budget, and remaining token estimates plus the
percentage used. The extension recalculates it for every request, never adds it
to session history, and removes it when pressure falls.

## Long-term memory design

[Mastra's Observational Memory research](https://mastra.ai/research/observational-memory)
reports that a stable observation block plus recent raw messages performs well
on LongMemEval. Its implementation also uses temporal anchors, periodic
reflection, and source-linked recall. This extension keeps the parts that fit
Pi's session model: one bounded observation, a retained raw tail, native
timestamps, and exact-entry recall.

Pi already chooses token thresholds and retained-tail boundaries. Reusing those
boundaries avoids a second scheduler, background buffer, or memory store. The
tradeoff is that each compaction rewrites the observation instead of appending
to an observation log. This invalidates the changed prompt prefix at compaction
boundaries, but keeps the context stable between them. A separate reflector or
semantic index should require a workload benchmark before adding that state.

## Validation

From `hm/shared/programs/pi`:

```bash
pnpm run check
node --import tsx --test extensions/ctx/test.ts
```
