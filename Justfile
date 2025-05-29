# Default recipe to show available commands
default:
    @just --list

# --- Helper Recipes ---

# Internal recipe for nix flake update logic
_nix_update *args:
    @if [ -z '{{args}}' ]; then \
        echo "Running: nix flake update"; \
        nix flake update; \
    else \
        echo "Running: nix flake update {{args}}"; \
        nix flake update {{args}}; \
    fi

# Internal recipe for brew update (macOS only)
_brew_update:
    @echo "Running: brew update"
    @brew update || (echo "Brew update failed, continuing with Nix update..."; exit 0)

# --- Main Recipes ---

# Update nixpkgs and brew for darwin
[macos]
update: _brew_update
    @just _nix_update "nixpkgs-darwin nixpkgs-darwin-unstable"

# Update nixpkgs for NixOS
[linux]
update:
    @just _nix_update "nixpkgs nixpkgs-unstable"

# Update all flake inputs
update-all:
    @just _nix_update

# Switch command
[macos]
switch:
    @echo "Running: sudo darwin-rebuild switch --flake ."
    @sudo darwin-rebuild switch --flake .

[linux]
switch:
    @echo "Running: sudo nixos-rebuild switch --flake ."
    @# NixOS switch usually requires root privileges
    @sudo nixos-rebuild switch --flake .

# Build command
[macos]
build:
    @echo "Running: darwin-rebuild build --flake ."
    @darwin-rebuild build --flake .
    @echo "--------------------------------------------------"
    @echo "Complete! Below is the diff-closures result:"
    @nix store diff-closures /run/current-system ./result
    @echo "--------------------------------------------------"
    @echo "Removing ./result symlink..."
    @unlink ./result

[linux]
build:
    @echo "Running: nixos-rebuild build --flake ."
    @# NixOS build usually does *not* require root privileges
    @nixos-rebuild build --flake .
    @echo "--------------------------------------------------"
    @echo "Complete! Below is the diff-closures result:"
    @nix store diff-closures /run/current-system ./result
    @echo "--------------------------------------------------"
    @echo "Removing ./result symlink..."
    @unlink ./result

# Deploy command
[macos]
deploy target_host:
    @echo "Deploying configuration to {{target_host}}..."
    @echo "Running: nix run nixpkgs#nixos-rebuild -- switch --flake .#{{target_host}} --target-host root@{{target_host}} --fast"
    @nix run nixpkgs#nixos-rebuild -- switch --flake .#{{target_host}} --target-host root@{{target_host}} --fast


[linux]
deploy target_host:
    @echo "Deploying configuration to {{target_host}}..."
    @echo "Running: nixos-rebuild switch --flake .#{{target_host}} --target-host root@{{target_host}}"
    @nixos-rebuild switch --flake .#{{target_host}} --target-host root@{{target_host}}

# Update nixpkgs for remote target
deploy-update:
    @just _nix_update "nixpkgs"

# Update all flakes for remote target
deploy-update-flake:
    @just _nix_update "nixpkgs home-manager agenix disko"

# List Generations command (macOS version)
[macos]
list-generations:
    #!/bin/sh -e
    if ! command -v darwin-rebuild > /dev/null; then
        echo "Error: 'darwin-rebuild' command not found in PATH."
        exit 1
    fi

    # Check for sudo privileges (needed for list)
    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for listing generations..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    echo "Available nix-darwin generations (requires sudo):"
    sudo darwin-rebuild --list-generations

# List Generations command (Linux version)
[linux]
list-generations:
    #!/bin/sh -e
    if ! command -v nixos-rebuild > /dev/null; then
        echo "Error: 'nixos-rebuild' command not found in PATH."
        exit 1
    fi

    # Check for sudo privileges (needed for list)
    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for listing generations..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    echo "Available NixOS generations (requires sudo):"
    sudo nixos-rebuild list-generations

# Rollback command (macOS version) - Takes generation number as argument
[macos]
rollback gen_num:
    #!/bin/sh -e
    # This recipe rolls back to a specific NixOS generation provided as an argument.

    GEN_NUM="{{gen_num}}" # Get generation number from just argument

    # Validate input
    if [ -z "$GEN_NUM" ]; then
      echo "Error: Generation number argument is required."
      echo "Usage: just rollback <generation_number>"
      exit 1
    fi
    if ! echo "$GEN_NUM" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid input: '$GEN_NUM' is not a valid generation number."
        exit 1
    fi

    # Check for darwin-rebuild command
    if ! command -v darwin-rebuild > /dev/null; then
        echo "Error: 'darwin-rebuild' command not found in PATH."
        exit 1
    fi

    # Check for sudo privileges (needed for switch)
    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for switching generation..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    # Construct the profile path
    PROFILE_PATH="/nix/var/nix/profiles/system-${GEN_NUM}-link"

    # Verify the profile path exists before attempting to switch
    # Use sudo to check because the path might require root to access/stat
    if ! sudo test -L "$PROFILE_PATH"; then
      echo "Error: Generation $GEN_NUM (profile path $PROFILE_PATH) does not exist."
      exit 1
    fi

    echo "Rolling back to generation $GEN_NUM (requires sudo)..."
    # Execute the switch using the specific profile path
    sudo darwin-rebuild switch -G "$GEN_NUM"

    echo "Rollback to generation $GEN_NUM complete!"

# Rollback command (Linux version) - Takes generation number as argument
[linux]
rollback gen_num:
    #!/bin/sh -e
    # This recipe rolls back to a specific NixOS generation provided as an argument.

    GEN_NUM="{{gen_num}}" # Get generation number from just argument

    # Validate input
    if [ -z "$GEN_NUM" ]; then
      echo "Error: Generation number argument is required."
      echo "Usage: just rollback <generation_number>"
      exit 1
    fi
    if ! echo "$GEN_NUM" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid input: '$GEN_NUM' is not a valid generation number."
        exit 1
    fi

    # Check for nixos-rebuild command
    if ! command -v nixos-rebuild > /dev/null; then
        echo "Error: 'nixos-rebuild' command not found in PATH."
        exit 1
    fi

    # Check for sudo privileges (needed for switch)
    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for switching generation..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    # Construct the profile path
    PROFILE_PATH="/nix/var/nix/profiles/system-${GEN_NUM}-link"

    # Verify the profile path exists before attempting to switch
    # Use sudo to check because the path might require root to access/stat
    if ! sudo test -L "$PROFILE_PATH"; then
      echo "Error: Generation $GEN_NUM (profile path $PROFILE_PATH) does not exist."
      exit 1
    fi

    echo "Rolling back to generation $GEN_NUM (requires sudo)..."
    sudo nix-env --switch-generation "$GEN_NUM" -p /nix/var/nix/profiles/system
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch

    echo "Rollback to generation $GEN_NUM complete!"


# --- Aliases ---
alias s := switch
alias b := build
alias u := update
