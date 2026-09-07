# Skill mechanics

Use this reference when creating or changing a Pi skill. For general instruction writing, see [Writing for agents](SKILL.md).

## Frontmatter and discovery

- A skill's `SKILL.md` requires `name` and a non-empty `description`. Use a name of 1–64 lowercase letters, digits, or hyphens, with no leading, trailing, or consecutive hyphens. Keep the description within 1024 characters.
- Describe the capability and concrete tasks that should trigger it. Pi normally includes discovered skill names and descriptions in the system prompt; the body loads on demand.
- Set `disable-model-invocation: true` when the skill should be omitted from that automatic discovery context. Keep its required description as a useful human-facing summary.
- Users can explicitly load a discovered skill with `/skill:name` when `enableSkillCommands` is enabled. Arguments after the command accompany the loaded content.

## Loading is not access control

Pi agents normally load skill bodies with `read`; there is no dedicated Skill tool required. `disable-model-invocation` hides the skill from the system prompt, not from filesystem access.

A document can point to any accessible reference, including a file inside a skill with model invocation disabled. Such a link does not automatically invoke the skill or grant permission to execute its instructions. Tool permissions, user authorization, and read-only task boundaries still apply.

Resolve relative reference, script, and asset paths against the directory containing `SKILL.md`, not the current working directory.

## References and routers

- Keep shared reference in one authoritative file. It can live inside a skill directory or elsewhere accessible; sharing alone does not require a new skill.
- Give each reference an explicit reading condition, such as “When diagnosing subscriptions, read …”. Keep common prerequisites and safety constraints in the entry document.
- A router skill names the relevant branches and their files. It can direct the agent to read another skill's instructions even when that skill is hidden from automatic discovery.
- Create a separate discoverable skill only when its independent task trigger justifies another always-loaded description.

Verify harness-specific behavior against the installed Pi skill documentation when changing these mechanics; discovery settings are not security boundaries.
