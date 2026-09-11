# systems [![Flake Check](https://github.com/Sped0n/systems/actions/workflows/flake-check.yml/badge.svg)](https://github.com/Sped0n/systems/actions/workflows/flake-check.yml)

## Overview

### Directory Structure

```
.
├── functions  # utility functions
├── hm         # home manager configurations
├── machines   # per device configurations
├── modules    # reuseable nix modules
├── overlays   # nixpkgs overlays
└── packages   # custom nix packages
```

### Machines

```
machines
├── esp-0       # Ubuntu desktop (x86_64)
├── iso         # NixOS installer image
├── srv-de-0    # NixOS server (x86_64)
├── srv-jp-0    # NixOS server (x86_64)
├── srv-nl-0    # NixOS server (x86_64)
├── srv-sg-0    # NixOS server (x86_64)
├── srv-sg-1    # NixOS server (aarch64)
└── wks-0       # macOS (aarch64)
```

## Usage (Justfile)

```
Available recipes:
    build                  # Build the local configuration and show closure changes. [alias: b]
    default                # Show all public recipes.
    deploy target_hosts    # Deploy configurations to one or more remote target hosts.
    hs flake               # Switch a standalone home-manager configuration.
    list-generations       # List available system generations for this host. [alias: lg]
    make-iso flake         # Build an ISO image from a machine name or full flake target.
    rollback gen_num       # Roll back to the specified system generation. [alias: rb]
    switch                 # Switch this machine to the new configuration. [alias: s]
    update-flakes          # Update shared flake inputs based on the current OS. [alias: uf]
    update-flakes-all      # Update all flake inputs across both macOS and Linux targets. [alias: ufa]
    update-pkgs            # Update unstable package channels. [alias: up]
    update-pkgs-all        # Update both stable and unstable package channels. [alias: upa]
    update-specific input  # Update only the specified flake inputs. [alias: us]
```

## Development

Enter the pinned development environment, install the Pi development graph,
and enable the repository checks:

```bash
nix develop # or `direnv allow`
pnpm --dir hm/shared/programs/pi install --frozen-lockfile
prek install
```
