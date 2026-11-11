---
description: Adapt this repository's Pi extensions to the pinned Pi release
argument-hint: "[release-range-or-url]"
---

Upgrade `hm/shared/programs/pi/extensions/` for the Pi version selected by
`flake.lock`. Optional release range or reference: $ARGUMENTS

1. Read the Pi configuration's instructions and maintenance documentation.
   Inspect the working tree and preserve existing work.
2. Determine the pinned Pi version and the previous version before synchronizing.
   If dependencies are already synchronized, use the supplied release range or
   Git diffs/history to establish the baseline; ask if it remains unclear.
3. Read upstream release notes for every intervening release. Inspect upstream
   APIs and local extension behavior where compatibility is uncertain. Distinguish
   required fixes from optional features; do not change extensions merely because
   a new API exists.
4. Run `pnpm --dir hm/shared/programs/pi run sync` to align dependencies and
   lockfiles with the Nix pin. Reuse this script rather than manually updating
   dependency versions or `lastChangelogVersion`.
5. Apply the smallest necessary extension changes. Add or adjust tests for
   concrete regressions and update affected extension documentation.
6. Check formatting of changed Pi files and run
   `pnpm --dir hm/shared/programs/pi run check`. Report unrelated failures without
   fixing them. Inspect the final diff for unintended changes.

Do not update flake inputs, upgrade to an unpinned Pi version, switch the system
configuration, or commit changes unless explicitly requested. If no extension
changes are needed, say so. Summarize the release range, changes, validation, and
any blockers with upstream references.
