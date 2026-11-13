# systems [![Flake Check](https://github.com/Sped0n/systems/actions/workflows/check.yml/badge.svg)](https://github.com/Sped0n/systems/actions/workflows/check.yml)

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
├── dlp-0       # macOS (aarch64)
├── esp-sh-0    # Ubuntu desktop (x86_64)
├── esp-sg-0    # Ubuntu desktop (x86_64)
├── srv-de-0    # NixOS server (x86_64)
├── srv-jp-0    # NixOS server (x86_64)
├── srv-nl-0    # NixOS server (x86_64)
├── srv-sg-0    # NixOS server (x86_64)
└── srv-sg-1    # NixOS server (aarch64)
```

## Usage (Justfile)

```
Available recipes:
    build                  # Build the local configuration and show closure changes. [alias: b]
    default                # Show all public recipes.
    deploy target_hosts    # Deploy configurations to one or more remote target hosts.
    hs [configuration] [--force] # Switch the local Home Manager configuration.
    list-generations       # List available system generations for this host. [alias: lg]
    rollback gen_num       # Roll back to the specified system generation. [alias: rb]
    switch                 # Switch this machine to the new configuration. [alias: s]
    update-flakes          # Update shared flake inputs based on the current OS. [alias: uf]
    update-flakes-all      # Update all flake inputs across both macOS and Linux targets. [alias: ufa]
    update-pkgs            # Update unstable package channels. [alias: up]
    update-pkgs-all        # Update both stable and unstable package channels. [alias: upa]
    update-specific input  # Update only the specified flake inputs. [alias: us]
```
