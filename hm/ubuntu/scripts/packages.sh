#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.

prepare() {
    (($# == 0)) || usage
    packages=(ssh-askpass-gnome zram-tools)
}

check() {
    for package in "${packages[@]}"; do
        if ! dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii '; then
            mismatch "APT package $package is missing."
        fi
    done
}

apply() {
    sudo apt-get update
    sudo apt-get install --yes "${packages[@]}"
}
