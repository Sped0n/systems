# Context management

Ctx uses [VCC](https://arxiv.org/abs/2603.29678)-style typed views for deterministic
compaction and source-linked recall. Pi's session JSONL is the only durable store.
Compilation, compaction, and tool retrieval make no model calls and infer no
task state.

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

- **Full:** original sanitized text, including tool arguments and results;
  images are metadata only.
- **UI:** chronological dialogue and folded tool calls with source pointers.
- **Adaptive:** matching source blocks, ranked and labeled by role, with bounded
  recorded call/result evidence when the association is unambiguous and original
  user-turn anchors for context, not renewed approval.

Pointers use `entryId:start-end`: zero-based, end-exclusive UTF-16 offsets in
the full textual view. Use `recall` with `target=entryId, offset=start` to read
one. Canonical replacements point to context-edit entries; originals remain
readable. Tool calls, results, and approvals are not interchangeable evidence.

## Compaction

Pi owns scheduling, model capacity, safe recent-tail boundaries, persistence,
and recovery. Ctx rebuilds older dialogue from source, respects canonical edits,
and leaves the native recent tail unduplicated.

Briefs use at most an estimated one-eighth of capacity, capped at 8,192 tokens.
Selection prioritizes original user evidence, then recent work, preserving
chronology and marking omissions. Unused space from short user messages goes to
clipped user text before older work. Older large tool results may also be masked
in the provider view with recall pointers; storage is unchanged.

Use `/compact [focus]` manually. Focus is a bounded note, not a selection rule.
Compaction requires active recall; failure commits nothing and does not fall
back to a model summarizer.

Compaction preserves session history, but the brief can omit instructions.
Retrieve original instructions when scope or authorization is unclear, and ask
if ambiguity remains. Compaction never renews historical permission.

## Recall

`/recall [question]` asks the main model to retrieve evidence, cite source IDs,
and identify gaps. For example: `/recall What requirements still apply?`.
Recall always uses the active lineage, including history before compaction;
other branches and sessions are not searchable.

The model can also call the tool directly:

- `search`: case-insensitive literal OR matching, ranked by BM25-style relevance,
  then recency. Each page has up to five matches. A hit, any uniquely associated
  recorded call/result, and its optional historical user-turn anchor share a
  600-character excerpt budget. Turn anchors appear at most once per page. Excerpts
  retain explicit roles, matched terms, and source pointers. Context replacements are labeled but never
  paired as recorded execution. `offset` counts matches, not related evidence;
  restart at zero when the query changes.
- `files`: five recorded native `read`/`write`/`edit` operations, ordered by
  path then chronology. `target` is a case-insensitive literal path substring;
  empty lists all operations. `offset` skips operations, not files.
- `read`: up to 12,000 UTF-16 characters, including complete mutation payloads.
- `around`: five chronological entry excerpts surrounding an anchor.
