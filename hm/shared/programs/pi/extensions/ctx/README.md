# Context management

Model-triggered compaction with a separately budgeted working note, recent-tail
continuity, deterministic history retrieval, and progressive context-pressure
advice. There is no configuration file and no separate usage or reset tool.

## Tools

### `respawn({})`

Call `respawn` alone in its tool batch, without writing a summary. The tool
records the compaction request and ends that agent run. Once Pi settles, the
extension uses Pi's compaction preparation and makes one tool-free working-note
request through the active model registry, using the selected model and its
configured authentication and routing.

The request contains the previous summary and conversation being compacted,
including any split-turn prefix, followed by the retained recent tail. The tail
lets the summarizer reconcile older evidence with current intent and discard
superseded goals or decisions; it is not another section to summarize or duplicate.
Including it increases input usage but prevents a note based only on stale history.
In this summarization copy only, `write` contents and `edit` replacement payloads
are replaced with omission markers. Operation names, paths, tool results, and
recent corrections remain available to the summarizer. Persisted messages and
Pi's retained tail are unchanged; `recall` can retrieve the original payloads.
The request asks for a few concise bullets covering the
active goal, essential constraints, unresolved decisions or blockers, and next
action, rather than accumulated completed-work inventories. Output is capped at
1,024 tokens, or the model's lower output limit. This is a generation budget,
not character validation followed by a retry. It does not inherit the working
agent's thinking-level setting; provider reasoning defaults still apply.

Pi deterministically selects the retained recent tail and keeps tool calls with
their results. The generated note and request usage are persisted in the native
compaction entry. This is in-place compaction, not a new session or empty context
window. Original evidence remains available through `recall`, following VCC's
retrieval-first principle.

This uses a separate summarization prompt, not the working conversation's
original request layout. Working-prefix cache reuse is not guaranteed. The
extension does not disable caching explicitly; provider defaults apply. The
output budget bounds generation, not input size, total cost, or wall-clock time.
Actual usage and latency need measurement with the chosen provider.

Use `respawn` at a useful task boundary before substantial work. Avoid respawning
with fresh context unless the user explicitly requests it. If nearly done,
finish directly. These are agent instructions, not hard usage gates or cooldowns.

After successful compaction, the agent continues from the note and retained
tail. If native automatic compaction reaches a pending respawn first, that
compaction makes the working-note request instead. The extension avoids a
second compaction and only supplies a continuation if Pi has not resumed.
There are no timers or idle polling.

Cancellation, provider failure, empty notes, tool calls, and token-limit stops
cancel the compaction without committing a partial note, retrying note generation,
falling through to native summarization, or starting a continuation. Original
history remains intact. Pi may decline to compact a session that is too small.
There is no save-only checkpoint mode. Historical notes are evidence, not
additional current instructions.

### `recall({ action, target, offset, scope })`

Search or read the current Pi session, including history hidden by compaction.
All four fields are required and meaningful in both modes:

```text
recall({ action: "search", target: "auth token", offset: 0, scope: "lineage" })
recall({ action: "search", target: "auth token", offset: 5, scope: "all" })
recall({ action: "read", target: "a1b2c3d4", offset: 0, scope: "lineage" })
recall({ action: "read", target: "a1b2c3d4", offset: 12000, scope: "lineage" })
```

For `search`, `target` contains case-insensitive literal keywords. An empty
string lists recent entries. Keywords use OR matching; terms found in fewer
recallable entries in the selected scope carry more weight, with newer entries
first on ties. `offset` is the number of matching entries to skip, starting at
zero. Each result page contains up to five 600-character snippets near the
rarest matched term, with stable session entry IDs. There is no regex engine
or model call inside retrieval.

For `read`, `target` is an exact entry ID returned by search. `offset` is the
number of UTF-16 characters to skip, starting at zero. Reads return up to 12,000
characters. Images are represented as metadata, not returned binary data.
Private custom-entry state, `!!` output, and recall-result echoes are excluded.

Search results include complete `Read: recall({...})` arguments for each entry.
Both modes include `Continue: recall({...})` when more remains; copy those
arguments to preserve the target, scope, and correct offset. These arguments
are also available in result details as `reads` and `next` (`null` at the end).

Use `scope: "lineage"` for the active branch. `scope: "all"` includes other
branches of this session, not other session files. Data comes directly from
Pi's current session manager, including in-memory sessions.

The flat, explicit action contract needs neither optional-field omission nor
object unions, and supports Pi's normal and strict provider serialization.

## User commands

`/recall` starts agent-led recovery of the current task. `/recall <request>`
focuses it on a natural-language question. The agent chooses keyword searches,
reads original entries, and verifies current files when necessary. This starts
a normal model turn, or queues a follow-up during an existing run; it requires
the `recall` tool to be active.

`/compact [instructions]` remains Pi's native manual compaction command.
There is no separate `/respawn` command.

## Context-pressure advice

The pre-compaction budget is:

```text
active model context window − Pi compaction.reserveTokens
```

At the end of a successful tool-using turn, the extension checks Pi's context
usage estimate. It sends advice for the highest crossed milestone:

| Budget used | Advice                                                                                  |
| ----------- | --------------------------------------------------------------------------------------- |
| 70%         | Consider checkpointing before another substantial step; finish directly if nearly done. |
| 85%         | Checkpoint at the next coherent boundary unless the task can finish now.                |
| 95%         | Checkpoint now if work remains; Pi's automatic compaction is approaching.               |

Thresholds round upward to whole tokens. Each level fires once per compaction
cycle and model-window/reserve combination. Jumps emit only the highest level.
Delivered reminder state lives in the session branch, so resume and tree
navigation do not require a separate cache. Old-cycle and old-budget reminders
are filtered out of model input, not deleted from history.

Advice is queued for the next response of an already tool-using turn. It does
not start another run after a final answer. No advice is sent while respawn is
pending, while the tool is inactive, when usage is unknown, when settings cannot
be read, or when automatic compaction is disabled.

Pi 0.85.1 does not expose its live compaction settings through extension context.
Reminder budgeting therefore uses Pi's native file-backed SettingsManager,
respecting project trust. SDK-only in-memory settings overrides are not visible
to this reminder calculation. Pi still owns the actual compaction boundary.

## Fallback and storage

With no pending respawn, automatic threshold/overflow compaction and manual
compaction remain Pi's normal model-based implementation. The extension never
changes Pi's compaction settings. Reminders are advice, not forced resets.

The extension writes no notes, indices, or configuration files. Handoffs are
stored in compaction entries; requests are ordinary tool results and reminders
are custom session messages. All original session entries remain available for recall.
There is no VCC summary compiler running alongside Pi's fallback.

The handoff prompt and recent tail encourage immediate task progress and
selective recall, but do not guarantee that a model never repeats compaction.
There are no progress heuristics, cooldowns, or reset circuit breakers.

## Validation and provenance

Run from `hm/shared/programs/pi`:

```bash
npm run check
node --import tsx --test extensions/ctx/test.ts
```

Tests run the real pinned Pi SDK with its in-memory faux model provider: tool
execution, native tail preparation, compaction commit order, cancellation,
automatic fallback, and continuation delivery are exercised without API calls.
Additional tests cover milestone escalation, persisted resume, branching,
normal/strict provider schema serialization, and a search-to-read agent run
that retrieves original evidence hidden by compaction.

The approach combines budgeted working notes with the retrieval workflow of
[VCC](https://github.com/lllyasviel/VCC). The text sanitizer derives from
[pi-vcc](https://github.com/sting8k/pi-vcc).
