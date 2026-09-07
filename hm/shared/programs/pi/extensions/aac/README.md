# AAC — Abolish All Compaction

AAC replaces automatic LLM summarization with agent-authored checkpoints and
local history recall. It runs in the current session and on the current model;
there is no helper agent, separate summarizer call, or project-local storage.

## Operation

The agent receives a private reminder near its working-context limit. It calls
`aac_checkpoint` alone with a concise goal, decisions and rationale, constraints,
unfinished work, next actions, and optional evidence IDs. The next model request
contains that checkpoint, the latest user request, and subsequent conversation.
The checkpoint tool's own exchange is omitted together, avoiding duplicate notes.

If the agent misses the reminder, AAC automatically keeps the previous checkpoint
marked stale, the latest user request, and a bounded recent tail. Parallel tool
calls and their results stay together. Large tool results are replaced only in
the outgoing view by references to their original entries. No original message
is rewritten or deleted.

The working budget is derived from the selected model's window, system prompt,
and active tools, with conservative UTF-8 estimates and output headroom. It is
capped at 64,000 estimated tokens. A reminder starts at 70% of that budget;
automatic rollover targets 40%, subject to fitting the checkpoint and latest
request. These are fixed implementation limits, not configuration settings.
Actual provider tokenization can differ.

If the latest request and checkpoint cannot fit, AAC aborts with a hint to
shorten the request or select a larger-context model. It does not silently
truncate the latest user request or retry indefinitely.

## Agent tools

### `aac_checkpoint`

```text
aac_checkpoint({
  checkpoint: "Goal, decisions, constraints, unfinished work, and next actions",
  sourceIds: ["original-entry-id"]
})
```

The checkpoint is limited to 6,000 characters and up to 16 active-branch source
IDs. Call it alone after other tools finish, not on every turn. Successful
execution means the state has been appended to the existing session; the view
changes before the next model request. Cancellation before execution saves
nothing. A saved checkpoint remains available if the run is interrupted later.

### `aac_recall`

```text
aac_recall({ query: "migration rollback" })
aac_recall({ id: "original-entry-id", offset: 6000 })
aac_recall({ query: "rejected approach", scope: "session" })
```

With no query, returns recent entries. Search uses case-insensitive literal
words, all of which must match, newest first. It returns up to five excerpts and
a continuation offset. Expanding an ID returns up to 6,000 characters; use the
returned character offset for the next portion.

Default scope is `branch`, the active lineage. Explicit `scope: "session"`
includes other branches of the same session. Results identify the entry, parent,
timestamp, and whether it belongs to the active branch. Checkpoints remain
branch-local regardless of recall scope. There is no cross-session search.
Recall exposes textual content and tool arguments; binary images remain in the
original session and are not re-emitted by the recall tool.

## Persistence and compatibility

Checkpoint text, evidence references, and window boundaries are `aac-window`
custom entries in Pi's session JSONL. Resume and `/reload` recover them directly;
`/tree` and forks select state from their own ancestry. No additional database,
index files, or `$CWD/.pi` files are created. Ephemeral sessions retain history
only for their process lifetime. Removing AAC leaves the original transcript
intact, but disables its projected working windows. AAC bounds provider input,
not Pi's in-memory transcript; context assembly scans session history without a
persisted index.

AAC uses public extension hooks. Native threshold compaction is cancelled.
Manual `/compact` is still a built-in Pi command and cannot be unregistered;
AAC cancels it with a short explanation when Pi reaches the compaction hook.
If Pi rejects compaction before that hook, its own message is shown instead.

For a provider overflow, AAC supplies a native compaction **record**, containing
existing carryover rather than a generated summary, so Pi can perform its single
recovery retry. The retry uses a smaller AAC budget. Keep Pi's automatic
compaction enabled for this retry plumbing. Pi can reject an overflow before
emitting the hook; in that case the provider error remains visible and no retry
is invented. AAC does not replace explicit `/tree` branch summarization.

Review keeps the current model and enables the AAC tools if they were active
before review. Other context extensions run in Pi's normal handler order;
transformations after AAC can change its outgoing view. Pi's displayed usage is
provider/host telemetry, not an exact preview of AAC's next request.

## References

The design combines [pi-vcc](https://github.com/sting8k/pi-vcc)'s local recall,
[Codex](https://github.com/openai/codex)'s checkpoint-and-rollover approach, and
[Tape](https://tape.systems)'s preserved history / constructed view distinction.
It does not copy pi-vcc's heuristic extraction pipeline.
