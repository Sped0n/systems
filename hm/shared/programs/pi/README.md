# Pi Configuration

Home Manager configuration for Pi Coding Agent. Enable it with
`programs.my-pi.enable`.

## Structure

```text
pi/
├── default.nix         # Home Manager module, secret wiring, and mapped configuration
├── wrapper.nix         # Pi executable wrappers and isolated runtime dependencies
├── AGENTS.md           # Minimal coding and papercut guidance
├── settings.json       # Non-model Pi global settings
├── keybindings.json    # TUI keybindings
├── models.json         # Circe providers and model catalog
├── tiers.json          # Named model selection
├── interceptor.json    # Ordered global file and Bash interception rules
├── extensions/         # Auto-discovered TypeScript extensions
├── skills/             # Auto-discovered Agent Skills
├── scripts/            # Standalone CLI and dependency maintenance entry points
├── themes/             # Auto-discovered Pi themes
├── .oxfmtrc.json       # Prettier-compatible Oxfmt settings
├── .prettierignore     # Shared editor and Oxfmt exclusions
├── package.json        # Development dependencies and maintenance commands
├── pnpm-lock.yaml      # Pinned development dependency graph
├── pnpm-workspace.yaml # Explicit dependency build-script approvals
├── runtime/            # Minimal independently pinned Nix runtime graph
└── tsconfig.json       # Extension typechecking
```

Four JSON configuration files, `AGENTS.md`, and all resource directories are
mapped with out-of-store symlinks. Home Manager generates `settings.json`,
deriving Pi's primary defaults from the default tier; changing that tier
requires a Home Manager rebuild.

Every extension lives under `extensions/<name>/`, with `index.ts` as its entry
point and a `README.md` describing its interface and behavior. Keep focused
tests beside the extension as `test.ts`.

Skills with an upstream source record its repository and pinned revision in
`metadata.source` and `metadata.commit`. Preserve upstream frontmatter and body
content when refreshing; provenance metadata should normally be the only diff.
`write-discoverable-code` is an intentional Tiger Style fork and records both
upstream revisions.

## Testing

Enter the repository development shell and install the pinned dependencies:

```bash
nix develop
pnpm --dir hm/shared/programs/pi install --frozen-lockfile
```

From this directory, run formatting, strict typechecking, and all extension tests:

```bash
pnpm run format
pnpm run check
```

The root pnpm development manifest and minimal npm runtime manifest intentionally
remain separate so Nix does not fetch the full development graph for deployed
extensions. `runtime/package.json` and `runtime/package-lock.json` own the
runtime dependency set. Update it to the latest versions and synchronize the
resulting exact versions into the root development manifest with:

```bash
pnpm run update:runtime-deps
```

A test rejects version drift between the two manifests.

Run the Home Manager evaluations from the repository root:

```bash
nix eval --raw 'path:.#homeConfigurations."esp-0".activationPackage.drvPath'
nix eval --raw 'path:.#darwinConfigurations."wks-0".system.drvPath'
```

Use the `path:` form while new files are untracked; normal Git-flake evaluation
only sees files present in the Git index.
