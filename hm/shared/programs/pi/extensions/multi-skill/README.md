# Multi-skill prompts

Start a prompt with space-separated skill commands:

```text
/skill:fast-rust /skill:coding-style Review this parser for unnecessary allocations.
```

Use Tab to insert the first skill without sending it. For each subsequent skill,
type `/skill:` to complete a skill you haven’t selected yet. Pi loads each
selected skill once per turn, even if you type it twice. Single-skill prompts
use Pi’s normal handling.
