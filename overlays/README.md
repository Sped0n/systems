# overlays

## Overview

`overlays/` contains `nixpkgs` overlays used by this flake. Overlays are loaded automatically from this directory and applied to the package set.

Supported entry types:

- `*.nix` files (e.g. `99-swift.nix`)
- directories containing `default.nix` (e.g. `swift/default.nix`)

Overlay order is **lexicographic by file/directory name**. Use numeric prefixes (`10-...`, `99-...`) to make ordering explicit.

## Writing an overlay

### Plain overlay (no extra inputs)

A plain overlay is a function:

```nix
final: prev: {
  # overrides/additions
}
```

### Input-aware overlay (recommended for flake inputs)

If an overlay needs flake inputs, write it as a “factory”:

```nix
{ inputs, ... }:
final: prev: {
  # use inputs.<name> here
}
```

The overlay loader will apply the factory with the provided args (e.g. `inputs`) and produce a regular `final: prev: ...` overlay.

### Platform-conditional attributes

Prefer `prev.stdenv.hostPlatform` inside overlays to avoid fixpoint recursion:

```nix
final: prev:
let
  is_darwin = prev.stdenv.hostPlatform.isDarwin;
in
{ }
  // prev.lib.optionalAttrs is_darwin {
    # darwin-only overrides
  }
```

## Example: Swift from `nixpkgs-swift`

`overlays/99-swift.nix`:

```nix
# see https://github.com/NixOS/nixpkgs/issues/483584
{ inputs, ... }:
final: prev:
let
  system = prev.stdenv.hostPlatform.system;
  pkgs_swift = inputs.nixpkgs-swift.legacyPackages.${system};
in
{
  swift = pkgs_swift.swift;
  swiftPackages = pkgs_swift.swiftPackages;
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  dotnetCorePackages = pkgs_swift.dotnetCorePackages; # marksman
}
```

## Quick checks

Evaluate a package to confirm the overlay took effect:

```bash
nix eval .#darwinConfigurations.wks-0.pkgs.swift.version
# or
nix eval .#nixosConfigurations.srv-de-0.pkgs.swift.version
```

If an overlay causes recursion, first ensure it doesn’t reference `final.stdenv` (use `prev.stdenv` for platform/system queries).
