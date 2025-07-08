# Default recipe to show available commands
default:
    @just --list

# --- Helper Recipes -----------------------------------------------------------

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

# --- Packages -----------------------------------------------------------------

# Update unstable packages and brew
[macos]
update-pkgs: _brew_update
    @just _nix_update "nixpkgs-darwin-unstable"

# Update unstable packages
[linux]
update-pkgs:
    @just _nix_update "nixpkgs-unstable"

# Update all packages
[macos]
update-pkgs-all: _brew_update
    @just _nix_update "nixpkgs-darwin nixpkgs-darwin-unstable"

# Update all packages
[linux]
update-pkgs-all:
    @just _nix_update "nixpkgs nixpkgs-unstable"

# Update specific flakes
update-specific input:
    @just _nix_update {{input}}

# --- Flakes -------------------------------------------------------------------

# Update flakes
[macos]
update-flakes:
    @just _nix_update "home-manager-darwin agenix-darwin nix-darwin nix-homebrew"

# Update flakes
[linux]
update-flakes:
    @just _nix_update "home-manager agenix disko"

# --- Build and Switch ---------------------------------------------------------

# Build the configuration and show diff-closures
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

# Build the configuration and show diff-closures
[linux]
build:
    @echo "Running: nixos-rebuild build --flake ."
    @nixos-rebuild build --flake .
    @echo "--------------------------------------------------"
    @echo "Complete! Below is the diff-closures result:"
    @nix store diff-closures /run/current-system ./result
    @echo "--------------------------------------------------"
    @echo "Removing ./result symlink..."
    @unlink ./result

# Switch to the new configuration
[macos]
switch:
    @echo "Running: sudo darwin-rebuild switch --flake ."
    @sudo darwin-rebuild switch --flake .

# Switch to the new configuration
[linux]
switch:
    @echo "Running: sudo nixos-rebuild switch --flake ."
    @sudo nixos-rebuild switch --flake .

# --- Deploy -------------------------------------------------------------------

# Deploy the configuration to a target host
deploy target_host:
    @echo "Deploying configuration to {{target_host}}..."
    @echo "Running: nixos-rebuild switch --flake .#{{target_host}} --build-host root@suisei --target-host root@{{target_host}} --fast --use-substitutes"
    @TMP_SCRIPT=$(mktemp); \
    trap 'rm -f "$TMP_SCRIPT"' EXIT; \
    sed "s/ssh:\/\//ssh-ng:\/\//g" $(which nixos-rebuild) > "$TMP_SCRIPT"; \
    chmod +x "$TMP_SCRIPT"; \
    "$TMP_SCRIPT" switch --flake .#{{target_host}} --build-host root@suisei --target-host root@{{target_host}} --fast --use-substitutes

# Update unstable packages for the target hosts
deploy-update-pkgs:
    @just _nix_update "nixpkgs-unstable"

# Update all packages for the target hosts
deploy-update-pkgs-all:
    @just _nix_update "nixpkgs nixpkgs-unstable"

# Update flakes for the target hosts
deploy-update-flakes:
    @just _nix_update "home-manager agenix disko"

# --- Rollback -----------------------------------------------------------------

# List available generations
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

# List available generations
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

# Rollback to a specific generation
[macos]
rollback gen_num:
    #!/bin/sh -e

    GEN_NUM="{{gen_num}}"

    if [ -z "$GEN_NUM" ]; then
      echo "Error: Generation number argument is required."
      echo "Usage: just rollback <generation_number>"
      exit 1
    fi
    if ! echo "$GEN_NUM" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid input: '$GEN_NUM' is not a valid generation number."
        exit 1
    fi

    if ! command -v darwin-rebuild > /dev/null; then
        echo "Error: 'darwin-rebuild' command not found in PATH."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for switching generation..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    PROFILE_PATH="/nix/var/nix/profiles/system-${GEN_NUM}-link"

    if ! sudo test -L "$PROFILE_PATH"; then
      echo "Error: Generation $GEN_NUM (profile path $PROFILE_PATH) does not exist."
      exit 1
    fi

    echo "Rolling back to generation $GEN_NUM (requires sudo)..."
    sudo darwin-rebuild switch -G "$GEN_NUM"

    echo "Rollback to generation $GEN_NUM complete!"

# Rollback to a specific generation
[linux]
rollback gen_num:
    #!/bin/sh -e

    GEN_NUM="{{gen_num}}"

    if [ -z "$GEN_NUM" ]; then
      echo "Error: Generation number argument is required."
      echo "Usage: just rollback <generation_number>"
      exit 1
    fi
    if ! echo "$GEN_NUM" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid input: '$GEN_NUM' is not a valid generation number."
        exit 1
    fi

    if ! command -v nixos-rebuild > /dev/null; then
        echo "Error: 'nixos-rebuild' command not found in PATH."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges for switching generation..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

    PROFILE_PATH="/nix/var/nix/profiles/system-${GEN_NUM}-link"

    if ! sudo test -L "$PROFILE_PATH"; then
      echo "Error: Generation $GEN_NUM (profile path $PROFILE_PATH) does not exist."
      exit 1
    fi

    echo "Rolling back to generation $GEN_NUM (requires sudo)..."
    sudo nix-env --switch-generation "$GEN_NUM" -p /nix/var/nix/profiles/system
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch

    echo "Rollback to generation $GEN_NUM complete!"

# --- Aliases ------------------------------------------------------------------

alias s := switch
alias b := build
alias up := update-pkgs
alias upa := update-pkgs-all
alias uf := update-flakes
alias us := update-specific
alias dup := deploy-update-pkgs
alias dupa := deploy-update-pkgs-all
alias duf := deploy-update-flakes
