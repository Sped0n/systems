# Turn-boundary compaction

Prevents uninterrupted assistant → tool → provider loops from running past Pi's
context budget. Pi normally checks its automatic compaction threshold only after
the agent run settles; this extension checks context usage after every completed
turn.

At 90% context usage, the extension:

1. aborts after the completed turn, when all tool results are finalized;
2. waits for the agent run to settle;
3. invokes Pi's native compaction lifecycle, producing a normal compaction entry.

The extension does not inject a continuation prompt after compaction. Queued
steering or follow-up messages remain owned by Pi; without one, the run stays
stopped until the user sends another message.

If Pi performs threshold compaction while the aborted run is settling, the
extension adopts that result instead of compacting twice. Overflow compaction
with automatic retry remains entirely owned by Pi.

The extension does not replace Pi's summarizer or modify provider payloads. Its
90% threshold is intentionally earlier than Pi's built-in reserve-token
threshold and applies to every model.
