#!/usr/bin/env bash
# curl -fsSL https://raw.githubusercontent.com/Sped0n/systems/main/docs/provisioning/inspect-host.sh | bash
set -euo pipefail

temporary_directory=""
cleanup() {
    if [[ -n "$temporary_directory" ]]; then
        rm -rf "$temporary_directory"
    fi
}
trap cleanup EXIT

section() {
    printf '\n== %s ==\n' "$1"
}

section "System"
uname -a

if command -v ip >/dev/null 2>&1; then
    section "IP addresses"
    ip -brief address

    section "IPv4 routes"
    ip route

    section "IPv6 routes"
    ip -6 route
fi

if command -v lsblk >/dev/null 2>&1; then
    section "Block devices"
    lsblk --output NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
fi

if command -v free >/dev/null 2>&1; then
    section "Memory"
    free --human
fi

section "SSH host public keys"
found_host_key=false
for host_key in /etc/ssh/ssh_host_*_key.pub; do
    if [[ -r "$host_key" ]]; then
        printf '%s: ' "$host_key"
        cat "$host_key"
        found_host_key=true
    fi
done
if [[ "$found_host_key" == false ]]; then
    printf 'No readable SSH host public keys found.\n'
fi

section "NixOS hardware configuration"
if command -v nixos-generate-config >/dev/null 2>&1; then
    temporary_directory="$(mktemp -d)"
    if nixos-generate-config --no-filesystems --root "$temporary_directory" >/dev/null; then
        cat "$temporary_directory/etc/nixos/hardware-configuration.nix"
    else
        printf 'nixos-generate-config could not inspect this host.\n' >&2
    fi
else
    printf 'nixos-generate-config is unavailable; see docs/provisioning/troubleshooting.md.\n'
fi
