# systems

## Overview

### Directory structure

```
.
├── docs       # documentation
├── home       # home manager configurations
├── machines   # per device configurations
├── modules    # reuseable nix modules
├── overlays   # nixpkgs overlays
└── packages   # custom nix packages
```

### Machines

```
machines
├── dendrobium    # macOS (aarch64)
├── stargazer     # NixOS desktop (x86_64)
├── unicorn       # NixOS server (x86_64)
├── banshee       # NixOS server (x86_64)
├── calibarn      # NixOS server (aarch64)
└── exia          # NixOS server (x86_64)
```

## Usage (Justfile)

```
Available recipes:
    build                  # Build the configuration and show diff-closures [alias: b]
    default                # Default recipe to show available commands
    deploy target_host     # Deploy the configuration to a target host
    deploy-update-flakes   # Update flakes for the target hosts [alias: duf]
    deploy-update-pkgs     # Update unstable packages for the target hosts [alias: dup]
    deploy-update-pkgs-all # Update all packages for the target hosts [alias: dupa]
    list-generations       # List available generations
    rollback gen_num       # Rollback to a specific generation
    switch                 # Switch to the new configuration [alias: s]
    update-flakes          # Update flakes [alias: uf]
    update-pkgs            # Update unstable packages [alias: up]
    update-pkgs-all        # Update all packages [alias: upa]
    update-specific input  # Update specific flakes [alias: us]
```
