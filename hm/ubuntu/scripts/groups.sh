#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.

prepare() {
    (($# == 0)) || usage
    groups=(dialout plugdev)
}

check() {
    for group in "${groups[@]}"; do
        if ! id -nG "$workstation_user" | tr ' ' '\n' | grep -Fxq "$group"; then
            mismatch "$workstation_user is not a member of $group."
        elif [[ "$EUID" -ne 0 ]] && ! id -nG | tr ' ' '\n' | grep -Fxq "$group"; then
            warn "$group membership is configured but not active in this session; log out and back in."
        fi
    done
}

apply() {
    for group in "${groups[@]}"; do
        if ! getent group "$group" >/dev/null; then
            sudo groupadd --system "$group"
        fi
        sudo usermod --append --groups "$group" "$workstation_user"
    done
    printf 'Log out and back in for new group memberships.\n'
}
