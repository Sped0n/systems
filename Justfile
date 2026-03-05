# =============================================================================
# Configuration Variables
# =============================================================================

detected_os := os()
os := if detected_os == "macos" { "darwin" } else { "linux" }

rebuild_cmd := if os == "darwin" { "darwin-rebuild" } else { "nixos-rebuild" }

stable_channel := "nixpkgs"
unstable_channel := "nixpkgs-unstable"
combined_channels := "nixpkgs nixpkgs-unstable"

pkgs_unstable := unstable_channel
pkgs_all := combined_channels

flake_shared := "determinate home-manager agenix llm-agents"
flake_darwin := flake_shared + " nix-darwin nix-homebrew"
flake_linux := flake_shared + " disko"
flakes := if os == "darwin" { flake_darwin } else { flake_linux }
flakes_all := flake_shared + " nix-darwin nix-homebrew disko"

current_system := "/run/current-system"
result_link := "./result"
system_profile := "/nix/var/nix/profiles/system"

# =============================================================================
# Default Recipe
# =============================================================================

# Show all public recipes.
default:
    @just --list

# =============================================================================
# Core Helper Functions
# =============================================================================

# Run `nix flake update` with optional input arguments.
_nix_update *args:
    @if [ -z '{{args}}' ]; then \
        echo "Running: nix flake update"; \
        nix flake update; \
    else \
        echo "Running: nix flake update {{args}}"; \
        nix flake update {{args}}; \
    fi

# Update Homebrew package metadata on macOS.
[macos]
_brew_update:
    @echo "Running: brew update"
    @brew update || (echo "Brew update failed, continuing..."; exit 0)

# No-op Homebrew update on Linux.
[linux]
_brew_update:
    @echo "Skipping brew update (macOS only)"

# Build the system and print a closure diff against current state.
_build_with_diff:
    @echo "Running: {{rebuild_cmd}} build --flake ."
    @{{rebuild_cmd}} build --flake .
    @echo "--------------------------------------------------"
    @echo "Comparing..."
    @nvd -- diff {{current_system}} {{result_link}}
    @echo "--------------------------------------------------"
    @echo "Removing {{result_link}} symlink..."
    @unlink {{result_link}}

# Apply the built system configuration.
_switch:
    @echo "Running: sudo {{rebuild_cmd}} switch --flake ."
    @sudo {{rebuild_cmd}} switch --flake .

# Validate that the rollback generation argument is present and numeric.
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

# Ensure rebuild command and sudo access are available.
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

# Update unstable package channels.
update-pkgs: _brew_update
    @just _nix_update "{{pkgs_unstable}}"

# Update both stable and unstable package channels.
update-pkgs-all: _brew_update
    @just _nix_update "{{pkgs_all}}"

# Update only the specified flake inputs.
update-specific input:
    @just _nix_update {{input}}

# Update shared flake inputs based on the current OS.
update-flakes:
    @just _nix_update "{{flakes}}"

# Update all flake inputs across both macOS and Linux targets.
update-flakes-all:
    @just _nix_update "{{flakes_all}}"

# =============================================================================
# Build and Switch Operations
# =============================================================================

# Build the local configuration and show closure changes.
build:
    @just _build_with_diff

# Build an ISO image from a machine name or full flake target.
make-iso flake:
    #!/usr/bin/env bash
    set -euo pipefail

    target="{{flake}}"
    case "$target" in
        .#nixosConfigurations.*)
            target="path:$(pwd)${target#.}"
            ;;
        .#*)
            machine="${target#.#}"
            target="path:$(pwd)#nixosConfigurations.${machine}.config.system.build.isoImage"
            ;;
    esac

    echo "Running: nix build $target -L"
    nix build "$target" -L

# Switch this machine to the new configuration.
switch:
    @just _switch

# =============================================================================
# Generation Management
# =============================================================================

# List available system generations for this host.
list-generations:
    @just _check_rebuild_prereqs
    @echo "Available {{os}} generations (requires sudo):"
    @sudo {{rebuild_cmd}} {{ if os() == "macos" { "--list-generations" } else { "list-generations" } }}

# Roll back to the specified system generation.
rollback gen_num:
    @just _validate_generation {{gen_num}}
    @just _check_rebuild_prereqs
    @just _rollback_{{os}} {{gen_num}}

# Perform rollback for nix-darwin systems.
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

# Perform rollback for NixOS systems.
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

# Deploy configurations to one or more remote target hosts.
deploy target_hosts:
    #!/bin/sh -e

    if [ -z "{{target_hosts}}" ]; then
        echo "Error: at least one target host is required."
        echo "Usage: just deploy <host1,host2,...>"
        exit 1
    fi

    if ! command -v nixos-deploy >/dev/null 2>&1; then \
        echo "Error: 'nixos-deploy' command not found."; \
        echo "Enable it with: programs.nixos-deploy.enable = true"; \
        exit 1; \
    fi
    deploy_cmd="$(command -v nixos-deploy)"

    if [ ! -t 0 ]; then
        echo "Error: deploy requires an interactive terminal to read sudo password."
        exit 1
    fi

    printf "Remote sudo password (used for all hosts): "
    trap 'stty echo 2>/dev/null || true' EXIT INT TERM
    stty -echo
    IFS= read -r deploy_sudo_password
    stty echo
    trap - EXIT INT TERM
    printf "\n"

    host_list=$(printf '%s' "{{target_hosts}}" | tr -d '[:space:]')
    if [ -z "$host_list" ]; then
        echo "Error: invalid target host list."
        echo "Usage: just deploy <host1,host2,...>"
        exit 1
    fi

    OLD_IFS="$IFS"
    set -f
    IFS=','
    set -- $host_list
    IFS="$OLD_IFS"
    set +f

    for target_host in "$@"; do
        if [ -z "$target_host" ]; then
            echo "Error: host list contains an empty entry."
            echo "Usage: just deploy <host1,host2,...>"
            exit 1
        fi

        target_expr=".#nixosConfigurations.${target_host}"

        set +e
        target_eval_output=$(nix eval --raw "${target_expr}.config.nixpkgs.system" 2>&1)
        eval_status=$?
        set -e

        if [ "$eval_status" -ne 0 ]; then
            echo "Error: could not determine system architecture for '$target_host'."
            printf '%s\n' "$target_eval_output"
            exit "$eval_status"
        fi

        target_system=$(printf '%s\n' "$target_eval_output" | tail -n1 | tr -d '\r\n')

        case "$target_system" in
            x86_64-*)
                build_host="builder-x86_64"
                ;;
            aarch64-*)
                build_host="builder-aarch64"
                ;;
            *)
                echo "Error: unsupported system architecture '$target_system' for '$target_host'."
                exit 1
                ;;
        esac

        echo "Deploying configuration to $target_host..."
        echo "Detected target system: $target_system"
        echo "Selected build host: $build_host"
        printf '%s\n' "$deploy_sudo_password" | "$deploy_cmd" ".#$target_host" "$build_host" "$target_host"
    done

    deploy_sudo_password=""

# =============================================================================
# Convenience Aliases
# =============================================================================

alias s := switch
alias b := build
alias up := update-pkgs
alias upa := update-pkgs-all
alias uf := update-flakes
alias ufa := update-flakes-all
alias us := update-specific
alias lg := list-generations
alias rb := rollback
