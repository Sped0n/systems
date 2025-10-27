# =============================================================================
# Configuration Variables
# =============================================================================

detected_os := os()
os := if detected_os == "macos" { "darwin" } else { "linux" }

rebuild_cmd := if os == "darwin" { "darwin-rebuild" } else { "nixos-rebuild" }
deploy_rebuild_cmd := "nixos-rebuild-ng"

stable_channel := "nixpkgs"
unstable_channel := "nixpkgs-unstable"
combined_channels := "nixpkgs nixpkgs-unstable"

pkgs_unstable := unstable_channel
pkgs_all := combined_channels

flakes_darwin := "determinate home-manager agenix nix-darwin nix-homebrew"
flakes_linux := "determinate home-manager agenix disko"
flakes := if os == "darwin" { flakes_darwin } else { flakes_linux }

deploy_flakes := flakes_linux
deploy_pkgs_unstable := unstable_channel
deploy_pkgs_all := combined_channels

current_system := "/run/current-system"
result_link := "./result"
system_profile := "/nix/var/nix/profiles/system"

# =============================================================================
# Default Recipe
# =============================================================================

default:
    @just --list

# =============================================================================
# Core Helper Functions
# =============================================================================

_nix_update *args:
    @if [ -z '{{args}}' ]; then \
        echo "Running: nix flake update"; \
        nix flake update; \
    else \
        echo "Running: nix flake update {{args}}"; \
        nix flake update {{args}}; \
    fi

[macos]
_brew_update:
    @echo "Running: brew update"
    @brew update || (echo "Brew update failed, continuing..."; exit 0)

[linux]
_brew_update:
    @echo "Skipping brew update (macOS only)"

_build_with_diff:
    @echo "Running: {{rebuild_cmd}} build --flake ."
    @{{rebuild_cmd}} build --flake .
    @echo "--------------------------------------------------"
    @echo "Comparing..."
    @nvd -- diff {{current_system}} {{result_link}}
    @echo "--------------------------------------------------"
    @echo "Removing {{result_link}} symlink..."
    @unlink {{result_link}}

_switch:
    @echo "Running: sudo {{rebuild_cmd}} switch --flake ."
    @sudo {{rebuild_cmd}} switch --flake .

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

update-pkgs: _brew_update
    @just _nix_update "{{pkgs_unstable}}"

update-pkgs-all: _brew_update
    @just _nix_update "{{pkgs_all}}"

update-specific input:
    @just _nix_update {{input}}

update-flakes:
    @just _nix_update "{{flakes}}"

# =============================================================================
# Build and Switch Operations
# =============================================================================

build:
    @just _build_with_diff

switch:
    @just _switch

# =============================================================================
# Generation Management
# =============================================================================

list-generations:
    @just _check_rebuild_prereqs
    @echo "Available {{os}} generations (requires sudo):"
    @sudo {{rebuild_cmd}} {{ if os() == "macos" { "--list-generations" } else { "list-generations" } }}

rollback gen_num:
    @just _validate_generation {{gen_num}}
    @just _check_rebuild_prereqs
    @just _rollback_{{os}} {{gen_num}}

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

deploy target_host:
    #!/bin/sh -e

    target_expr=".#nixosConfigurations.{{target_host}}"

    set +e
    target_eval_output=$(nix eval --raw "${target_expr}.config.nixpkgs.system" 2>&1)
    eval_status=$?
    set -e

    if [ "$eval_status" -ne 0 ]; then
        echo "Error: could not determine system architecture for '{{target_host}}'."
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
            echo "Error: unsupported system architecture '$target_system' for '{{target_host}}'."
            exit 1
            ;;
    esac

    echo "Deploying configuration to {{target_host}}..."
    echo "Detected target system: $target_system"
    echo "Selected build host: $build_host"
    echo "Running: {{deploy_rebuild_cmd}} switch --flake .#{{target_host}} --build-host $build_host --target-host {{target_host}} --sudo --ask-sudo-password --use-substitutes"

    {{deploy_rebuild_cmd}} switch --flake .#{{target_host}} \
        --build-host "$build_host" \
        --target-host "{{target_host}}" \
        --sudo \
        --ask-sudo-password \
        --use-substitutes

deploy-update-pkgs:
    @just _nix_update "{{deploy_pkgs_unstable}}"

deploy-update-pkgs-all:
    @just _nix_update "{{deploy_pkgs_all}}"

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
