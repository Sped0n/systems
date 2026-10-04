# Context management

Ctx combines a [VCC](https://arxiv.org/abs/2603.29678)-style trace compiler,
deterministic compaction, and LLM-assisted recall. Pi's session JSONL is the only
durable store; compaction makes no model calls.

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

One typed trace preserves roles and supplies three views:

- **Full:** original sanitized text, including tool arguments and results;
  images are metadata only.
- **UI:** chronological dialogue and folded tool calls with source pointers.
- **Adaptive:** matching source blocks, ranked and labeled by role.

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
chronology and marking omissions. Older large tool results may also be masked
in the disposable provider view, with recall pointers; storage is untouched.

Use `/compact [focus]` manually. Focus is retained as a bounded note, not
semantically processed. Compaction requires active recall; failure commits
nothing and does not fall back to a model summarizer.

**History is lossless; the brief is not.** Retrieve original instructions when
scope or authorization is unclear, and ask if ambiguity remains. Compaction
never renews historical permission.

## Recall

`/recall [question]` asks the main model to retrieve evidence, cite source IDs,
and identify gaps—for example, `/recall What requirements still apply?`.
The model can also call the tool directly:

- `search`: case-insensitive literal OR matching; five role-tagged snippets.
- `files`: five recorded native `read`/`write`/`edit` operations, ordered by
  path then chronology. `target` is a case-insensitive literal path substring;
  empty lists all operations. `offset` skips operations, not files.
- `read`: up to 12,000 UTF-16 characters, including complete mutation payloads.
- `around`: five chronological entry excerpts surrounding an anchor.
