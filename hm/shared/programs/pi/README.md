# Pi Configuration

Home Manager configuration for Pi Coding Agent. Enable it with
`programs.my-pi.enable`. `default.nix` installs a thin
wrapper around `pkgs.llm-agents.pi`, supplies age-managed API keys, and maps the
configuration into `~/.config/pi`.

Node.js, UV, and OpenSCAD are added only to the Pi wrappers' `PATH`; this module
does not install them into the user's global package environment.

## Structure

```text
pi/
├── default.nix         # Home Manager module, wrappers, and secret wiring
├── AGENTS.md           # Minimal coding and papercut guidance
├── settings.json       # Non-model Pi global settings
├── keybindings.json    # TUI keybindings
├── models.json         # Circe providers and model catalog
├── tiers.json          # Performance and economy model selection
├── interceptor.json    # Ordered global file and Bash interception rules
├── extensions/         # Auto-discovered TypeScript extensions
├── skills/             # Auto-discovered Agent Skills
├── scripts/            # Standalone CLI and dependency maintenance entry points
├── themes/             # Auto-discovered Pi themes
├── package.json        # Development dependencies and maintenance commands
├── package-lock.json   # Pinned development dependency graph
├── runtime/            # Minimal independently pinned Nix runtime graph
└── tsconfig.json       # Extension typechecking
```

Four JSON configuration files, `AGENTS.md`, and all resource directories are
mapped with out-of-store symlinks. Home Manager generates `settings.json`,
deriving Pi's primary defaults from the performance tier; changing that tier
requires a Home Manager rebuild.

Every extension lives under `extensions/<name>/`, with `index.ts` as its entry
point and a `README.md` describing its interface and behavior. Keep focused
tests beside the extension as `test.ts`.

Skills with an upstream source record its repository and pinned revision in
`metadata.source` and `metadata.commit`. Preserve upstream frontmatter and body
content when refreshing; provenance metadata should normally be the only diff.
`write-discoverable-code` is an intentional Tiger Style fork and records both
upstream revisions.

`tiers.json` is the single model-selection source. The performance tier supplies
Pi's primary defaults; `pcommit`, generated session names, isolated
summarization, and `delegate` use the economy tier. Select any configured tier
at startup with `pi --tier NAME`, or inspect and switch the current idle session
with `/tier [NAME]`.

The `delegate` tool provides narrow foreground context isolation for `explore`
and `bash` investigations. Its child Pi process loads project context, the
economy tier, and the interceptor, then returns only a bounded final report; see
`extensions/delegate/README.md` for its exact capability boundaries.

## Testing

Install the pinned test dependencies with Nix-provided Node.js:

```bash
nix shell nixpkgs#nodejs_24 -c npm ci --ignore-scripts
```

Run strict typechecking and all extension tests:

```bash
nix shell nixpkgs#nodejs_24 -c npm run check
```

The root and minimal runtime manifests intentionally remain separate so Nix does
not fetch the full development graph for deployed extensions. `runtime/package.json`
owns the runtime dependency set. Update it to the latest versions and synchronize
the resulting exact versions into the root development manifest with:

```bash
npm run update:runtime-deps
```

A test rejects version drift between the two manifests.

Run the Home Manager evaluations from the repository root:

```bash
nix eval --raw 'path:.#homeConfigurations."esp-0".activationPackage.drvPath'
nix eval --raw 'path:.#darwinConfigurations."wks-0".system.drvPath'
```

Use the `path:` form while new files are untracked; normal Git-flake evaluation
only sees files present in the Git index.
