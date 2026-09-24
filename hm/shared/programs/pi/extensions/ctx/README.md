# Context management

Ctx adds observational compaction, session recall, tool-result masking, and
context-pressure guidance. Pi's native session is the only durable source.
Original history stays intact; there are no sidecar files or external memory
services.

## Memory model

```text
                        ┌─ observer view ─> bounded Markdown observation
native session entries ─┼─ context view  ─> consumed large results masked
                        └─ recall view   ─> search and exact entry reads
                              │
                       native session entry IDs
```

Compaction preserves active constraints, current decisions, unresolved work, and
a next action alongside recent messages. Original user evidence takes precedence
over earlier summaries. Observations remain fallible; recall provides the source
when exact wording or authorization matters.

Pi owns compaction scheduling, retained tails, persistence, and branching.
Existing sessions need no migration.

## Usage

- `/compact [focus]` requests compaction with optional focus instructions.
- The `compact` tool requests compaction at a useful task boundary and skips
  redundant requests when context is still fresh. Call it alone.
- `/recall [request]` asks the agent to recover context from session history.
- The `recall` tool searches or reads exact entries. Use `lineage` for the active
  branch or `all` for every branch in this session, and copy returned arguments
  to continue reading. It does not search other sessions.

Input queued during compaction takes over the next turn without interrupting
compaction. Failed or cancelled compaction leaves history intact.

## Validation

Run `pnpm run check` from `hm/shared/programs/pi`.
