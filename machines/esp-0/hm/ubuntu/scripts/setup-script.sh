#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s [--check|--apply] [--interface <name> (OTBR only)]\n' "${0##*/}" >&2
    exit 2
}

mode="${1:---check}"
if (($# > 0)); then
    shift
fi
case "$mode" in
--check | --apply) ;;
*) usage ;;
esac

# shellcheck source=/dev/null
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
    printf 'error: This script supports Ubuntu only; detected %s.\n' "${ID:-unknown}" >&2
    exit 1
fi
workstation_user="${SUDO_USER:-$(id -un)}"
if [[ "$workstation_user" == root ]]; then
    printf 'error: Run this script from the workstation user account, not a root shell.\n' >&2
    exit 1
fi

warn() {
    printf 'warning: %s\n' "$*" >&2
}
needs_setup=false
mismatch() {
    warn "$@"
    needs_setup=true
}

setup_args=()
prepare "$@"
check

if [[ "$mode" == --check ]]; then
    if [[ "$needs_setup" == true ]]; then
        warn 'To repair these settings, run the following command and confirm its changes:'
        printf '  %q --apply' "$0" >&2
        if ((${#setup_args[@]} > 0)); then
            printf ' %q' "${setup_args[@]}" >&2
        fi
        printf '\n' >&2
    fi
    exit 0
fi

printf '\n%s\n' "$description"
read -r -p 'Type apply to continue: ' confirmation </dev/tty
[[ "$confirmation" == apply ]] || {
    printf 'Cancelled.\n'
    exit 0
}
sudo -v
apply
