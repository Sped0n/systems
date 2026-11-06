# Context management

Ctx uses typed views of Pi's session JSONL for compaction and recall. The JSONL
is the only persistent store. Compilation, compaction, and tool retrieval make
no model calls. Ctx does not infer task state.

The design draws on [VCC](https://arxiv.org/abs/2603.29678). That paper evaluates
structured views for memory reflection, not live compaction quality. See
[Replay evaluation](REPLAY.md) for local measurements and their limits.

```text
Pi session JSONL
  |
  v
Typed trace + source coordinates
  |-- Full view ------> recall read / around
  |-- UI view --------> compacted context + native recent tail
  `-- Adaptive view --> recall search
                            ^
                      /recall + main model
```

## Views

- The full view contains sanitized source text, including tool arguments and
  results. Images appear as metadata only. Recorded nested calls follow the
  original result, so existing UTF-16 offsets do not change. Nested records
  contain status and sometimes arguments, but no child-result bodies. Incomplete
  records are labeled.
- The UI view shows dialogue in chronological order and summarizes tool calls
  with source pointers. Complete skill expansions become `[skill: name]`.
  Surrounding user wording and fenced examples remain intact. Ctx does not track
  which skills are active.
- The adaptive view ranks matching source blocks and labels their roles. It
  includes excerpts from recorded calls and results when their association is
  unambiguous. It also includes the user message that started the turn. That
  message provides historical context, not renewed approval.

Pointers use `entryId:start-end`. These are zero-based, end-exclusive UTF-16
offsets in the full textual view. To read a pointer, call `recall` with
`action="read"`, `target=entryId`, and `offset=start`. Canonical replacements
point to context-edit entries. The originals remain readable. A tool call does
not prove success, and a tool result does not establish approval.

## Compaction

Pi controls when compaction runs, the model's context capacity, and which recent
messages remain uncompressed. Pi also handles persistence and recovery. Ctx
rebuilds older dialogue from source and applies canonical edits. It does not
duplicate the recent messages that Pi retains.

A brief uses at most an estimated one-eighth of the model's context capacity,
capped at 8,192 tokens. Ctx keeps the full UI view if it fits. Otherwise, it
selects user evidence first. It preserves the opening request and complete
messages before taking excerpts from larger messages. It presents the selected
evidence chronologically, marks omissions, and expands clipped wording if space
remains. There is no fixed percentage split between user messages and other work.

Ctx uses remaining space for pointers to the context of short replies, file
activity, and older assistant or tool excerpts. These cannot displace selected
user wording. File activity groups repeated operations and shows the latest
recorded call for each path. Its counts describe recorded operations, not current
file contents or successful edits. Pi's recent messages already include current
work.

Ctx may replace older large tool results with recall pointers in the context
sent to the provider. Recent work and recall results remain visible. This does
not change stored history.

Use `/compact [focus]` to compact manually. The focus becomes a length-limited
note. It does not control evidence selection. Compaction requires an active
recall tool. If compaction fails, Ctx saves no changes and does not call a model
to generate a summary.

The brief can omit instructions even though session history remains intact.
Retrieve the original instructions when scope or authorization is unclear. Ask
the user if ambiguity remains. Compaction never renews historical permission.

## Recall

`/recall [question]` asks the main model to retrieve evidence, cite source IDs,
and identify gaps. For example, use `/recall What requirements still apply?`.
Recall searches only the active lineage, including history before compaction.
It cannot search other branches or sessions.

The model can also call the tool directly with the following actions.

### Search

`search` uses case-insensitive literal OR matching. It ranks matches by
BM25-style relevance, then recency. Each page contains up to five matches.

Each match shares a 600-character excerpt budget with any uniquely associated
recorded call or result and the optional user message that started the turn.
That user message appears at most once per page. Excerpts include roles,
matched terms, and source pointers. Context replacements are labeled and are
never paired as recorded execution.

The `offset` counts matches, not related evidence. Restart at zero when the query
changes. "Expand if needed" supplies a read request for the first match, not for
the user message included as context.

### Files

`files` lists up to five recorded direct or nested `read`, `write`, or `edit`
operations per page, ordered by path, then chronology. Direct calls include result
pointers when the association is unambiguous. Nested records have status but no
recovered child-result body.

The `target` is a case-insensitive literal path substring. An empty target lists
all operations. The `offset` skips operations, not files. Ctx does not infer file
changes from shell scripts.

### Read

`read` returns up to 12,000 UTF-16 characters per page. Follow its continuation
requests to recover the full source text, including complete edit and write
payloads.

### Around

`around` returns up to five chronological entry excerpts surrounding an anchor.
