# =============================================================================
# Configuration Variables
# =============================================================================

# Platform detection
os := if os() == "macos" { "darwin" } else { "linux" }

# Platform-specific commands
rebuild_cmd := if os() == "macos" { "darwin-rebuild" } else { "nixos-rebuild" }
deploy_rebuild_cmd := "nixos-rebuild-ng"

# Platform-specific package inputs
pkgs_unstable := if os() == "macos" { "nixpkgs-darwin-unstable" } else { "nixpkgs-unstable" }
pkgs_all := if os() == "macos" { "nixpkgs-darwin nixpkgs-darwin-unstable" } else { "nixpkgs nixpkgs-unstable" }

# Platform-specific flake inputs
flakes := if os() == "macos" { "home-manager-darwin agenix-darwin nix-darwin nix-homebrew" } else { "home-manager agenix disko" }

# Deploy-specific inputs (always Linux)
deploy_flakes := "home-manager agenix disko"
deploy_pkgs_unstable := "nixpkgs-unstable"
deploy_pkgs_all := "nixpkgs nixpkgs-unstable"

# System paths
current_system := "/run/current-system"
result_link := "./result"
system_profile := "/nix/var/nix/profiles/system"

# =============================================================================
# Default Recipe
# =============================================================================

# Default recipe to show available commands
default:
    @just --list

# =============================================================================
# Core Helper Functions
# =============================================================================

# Execute nix flake update with optional arguments
_nix_update *args:
    @if [ -z '{{args}}' ]; then \
        echo "Running: nix flake update"; \
        nix flake update; \
    else \
        echo "Running: nix flake update {{args}}"; \
        nix flake update {{args}}; \
    fi

# Update brew (macOS only, with error handling)
[macos]
_brew_update:
    @echo "Running: brew update"
    @brew update || (echo "Brew update failed, continuing..."; exit 0)

# No-op for Linux
[linux]
_brew_update:
    @echo "Skipping brew update (macOS only)"

# Generic build command with diff-closures
_build_with_diff:
    @echo "Running: {{rebuild_cmd}} build --flake ."
    @{{rebuild_cmd}} build --flake .
    @echo "--------------------------------------------------"
    @echo "Complete! Below is the diff-closures result:"
    @nix store diff-closures {{current_system}} {{result_link}}
    @echo "--------------------------------------------------"
    @echo "Removing {{result_link}} symlink..."
    @unlink {{result_link}}

# Generic switch command
_switch:
    @echo "Running: sudo {{rebuild_cmd}} switch --flake ."
    @sudo {{rebuild_cmd}} switch --flake .

# Validate generation number
_validate_generation gen_num:
    #!/bin/sh -e
    if [ -z "{{gen_num}}" ]; then
        echo "Error: Generation number argument is required."
        echo "Usage: just rollback <generation_number>"
        exit 1
    fi
    if ! echo "{{gen_num}}" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid input: '{{gen_num}}' is not a valid generation number."
        exit 1
    fi

# Check command availability and sudo privileges
_check_rebuild_prereqs:
    #!/bin/sh -e
    if ! command -v {{rebuild_cmd}} > /dev/null; then
        echo "Error: '{{rebuild_cmd}}' command not found in PATH."
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        echo "Requesting sudo privileges..."
        sudo -v || { echo "Error: sudo privileges are required."; exit 1; }
    fi

# =============================================================================
# Package Management
# =============================================================================

# Update unstable packages
update-pkgs: _brew_update
    @just _nix_update "{{pkgs_unstable}}"

# Update all packages
update-pkgs-all: _brew_update
    @just _nix_update "{{pkgs_all}}"

# Update specific flake input
update-specific input:
    @just _nix_update {{input}}

# Update platform-specific flakes
update-flakes:
    @just _nix_update "{{flakes}}"

# =============================================================================
# Build and Switch Operations
# =============================================================================

# Build the configuration and show diff-closures
build:
    @just _build_with_diff

# Switch to the new configuration
switch:
    @just _switch

# =============================================================================
# Generation Management
# =============================================================================

# List available generations
list-generations:
    @just _check_rebuild_prereqs
    @echo "Available {{os}} generations (requires sudo):"
    @sudo {{rebuild_cmd}} {{ if os() == "macos" { "--list-generations" } else { "list-generations" } }}

# Rollback to a specific generation
rollback gen_num:
    @just _validate_generation {{gen_num}}
    @just _check_rebuild_prereqs
    @just _rollback_{{os}} {{gen_num}}

# macOS-specific rollback implementation
[macos]
_rollback_darwin gen_num:
    #!/bin/sh -e
    PROFILE_PATH="{{system_profile}}-{{gen_num}}-link"
    if ! sudo test -L "$PROFILE_PATH"; then
        echo "Error: Generation {{gen_num}} does not exist."
        exit 1
    fi
    echo "Rolling back to generation {{gen_num}}..."
    sudo darwin-rebuild switch -G "{{gen_num}}"
    echo "Rollback complete!"

# Linux-specific rollback implementation
[linux]
_rollback_linux gen_num:
    #!/bin/sh -e
    PROFILE_PATH="{{system_profile}}-{{gen_num}}-link"
    if ! sudo test -L "$PROFILE_PATH"; then
        echo "Error: Generation {{gen_num}} does not exist."
        exit 1
    fi
    echo "Rolling back to generation {{gen_num}}..."
    sudo nix-env --switch-generation "{{gen_num}}" -p {{system_profile}}
    sudo {{system_profile}}/bin/switch-to-configuration switch
    echo "Rollback complete!"

# =============================================================================
# Deployment (Remote Systems)
# =============================================================================

# Deploy configuration to target host
deploy target_host:
    @echo "Deploying configuration to {{target_host}}..."
    @echo "Running: {{deploy_rebuild_cmd}} switch --flake .#{{target_host}} --build-host root@suisei --target-host root@{{target_host}} --no-reexec --use-substitutes"
    @NIX_SSHOPTS="-o ControlMaster=no" {{deploy_rebuild_cmd}} switch --flake .#{{target_host}} --build-host root@suisei --target-host root@{{target_host}} --no-reexec --use-substitutes

# Update unstable packages for deployment targets
deploy-update-pkgs:
    @just _nix_update "{{deploy_pkgs_unstable}}"

# Update all packages for deployment targets
deploy-update-pkgs-all:
    @just _nix_update "{{deploy_pkgs_all}}"

# Update flakes for deployment targets
deploy-update-flakes:
    @just _nix_update "{{deploy_flakes}}"

# =============================================================================
# Convenience Aliases
# =============================================================================

alias s := switch
alias b := build
alias up := update-pkgs
alias upa := update-pkgs-all
alias uf := update-flakes
alias us := update-specific
alias dup := deploy-update-pkgs
alias dupa := deploy-update-pkgs-all
alias duf := deploy-update-flakes
alias lg := list-generations
alias rb := rollback
