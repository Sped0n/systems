---
description: Update selected local Nix packages and their source hashes
argument-hint: "<package> [package...]"
---

Bump the requested package(s) under `packages/`: $ARGUMENTS

1. If no packages were specified, ask which ones to update. Otherwise resolve the
   requested names through `packages/default.nix`; ask about unknown or ambiguous
   names rather than updating everything.
2. Read applicable instructions, package definitions, and related overlays.
   Inspect the working tree and preserve existing work.
3. Find each package's latest stable upstream release unless a particular
   version was requested. Use authoritative release/source information and read
   relevant upgrade notes. Do not downgrade or select prereleases implicitly.
   For revision-pinned sources without versioned releases, identify the upstream
   revision and review the relevant changes.
4. Update only the selected definitions and any directly required overlay
   changes. Fetch the actual target sources to compute hashes using the matching
   Nix fetcher; never invent hashes or leave placeholders. Preserve platform,
   architecture, licensing, and installation behavior. Review security-policy
   changes explicitly when updating packages such as `docker-seccomp`.
5. Format changed Nix files with `nixfmt`. Evaluate the affected derivations using
   the pinned nixpkgs and `packages/default.nix`; these local packages are not
   exposed as flake package outputs. Build affected packages where supported on
   the available host, without installing them. Report unavailable platform
   checks or other blockers rather than claiming they passed.
6. Inspect the final diff. Summarize old and new versions or revisions, source
   references, changed hashes, validation results, and any blockers.

Do not update unrelated packages or flake inputs, switch system configuration,
install packages, or commit changes unless explicitly requested. If a package is
already current, leave it unchanged.
