#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.
prepare() {
    (($# == 0)) || usage
}

check() {
    if [[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || true)" == 1 ]]; then
        mismatch 'AppArmor restricts unprivileged user namespaces. Disabling this relaxes a host-wide security restriction until reboot.'
    fi
}

apply() {
    sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
}
