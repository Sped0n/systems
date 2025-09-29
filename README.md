# systems

## Overview

### Directory structure

```
.
├── home       # home manager configurations
├── machines   # per device configurations
├── modules    # reuseable nix modules
├── overlays   # nixpkgs overlays
└── packages   # custom nix packages
```

### [Machines](https://github.com/Sped0n/systems/tree/main/machines)

```
machines
├── ringo       # macOS (arm64)
├── shigoto     # NixOS desktop (x86)
├── suisei      # NixOS server (aarch64)
├── tennousei   # NixOS server (x86)
└── tsuki       # NixOS server (x86)
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
