#!/usr/bin/env bash
# curl -fsSL https://raw.githubusercontent.com/Sped0n/systems/main/docs/provisioning/ubuntu-workstation.sh | bash -s -- --apply
set -euo pipefail

usage() {
    printf 'Usage: %s [--check|--apply] [--interface <name>]\n' "${0##*/}" >&2
    exit 2
}

mode=--check
main_interface=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check | --apply)
            mode="$1"
            shift
            ;;
        --interface)
            [[ $# -ge 2 ]] || usage
            main_interface="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done

# shellcheck source=/dev/null
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
    printf 'This helper supports Ubuntu only; detected %s.\n' "${ID:-unknown}" >&2
    exit 1
fi

workstation_user="${SUDO_USER:-$(id -un)}"
if [[ "$workstation_user" == root ]]; then
    printf 'Run this helper from the workstation user account, not a root shell.\n' >&2
    exit 1
fi
workstation_home="$(getent passwd "$workstation_user" | cut -d: -f6)"
[[ -n "$workstation_home" ]] || {
    printf 'Could not resolve the home directory for %s.\n' "$workstation_user" >&2
    exit 1
}

if [[ -z "$main_interface" ]]; then
    main_interface="$(
        ip -6 route show default 2>/dev/null |
            awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
    )"
fi
if [[ -z "$main_interface" ]]; then
    main_interface="$(
        ip route show default 2>/dev/null |
            awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
    )"
fi
[[ "$main_interface" =~ ^[A-Za-z0-9_.:-]+$ && -d "/sys/class/net/$main_interface" ]] || {
    printf 'Could not resolve network interface %s; pass --interface <name>.\n' "${main_interface:-<none>}" >&2
    exit 1
}

packages=(
    gnome-screenshot
    ssh-askpass-gnome
    zram-tools
)
groups=(dialout plugdev)
zram_config=/etc/default/zramswap

solaar_rules=""
if command -v solaar >/dev/null 2>&1; then
    solaar_store="$(readlink -f "$(command -v solaar)")"
    solaar_store="${solaar_store%/bin/solaar}"
    candidate="${solaar_store}/lib/udev/rules.d/42-logitech-unify-permissions.rules"
    [[ -f "$candidate" ]] && solaar_rules="$candidate"
fi

openocd_rules=""
openocd_root="$workstation_home/.espressif/tools/openocd-esp32"
if [[ -d "$openocd_root" ]]; then
    openocd_rules="$(
        find "$openocd_root" \
            -type f -path '*/share/openocd/contrib/60-openocd.rules' \
            -print | sort -V | tail -n 1
    )"
fi

printf 'Ubuntu:   %s\nUser:     %s\nInterface: %s\nMode:     %s\n' \
    "${VERSION_ID:-unknown}" "$workstation_user" "$main_interface" "${mode#--}"
printf '\nAPT packages:\n'
for package in "${packages[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii '; then
        printf '  installed  %s\n' "$package"
    else
        printf '  missing    %s\n' "$package"
    fi
done

printf '\nGroups:\n'
for group in "${groups[@]}"; do
    if id -nG "$workstation_user" | tr ' ' '\n' | grep -Fxq "$group"; then
        printf '  member     %s\n' "$group"
    else
        printf '  missing    %s\n' "$group"
    fi
done

printf '\nSystem configuration:\n'
printf '  zram service  %s\n' "$(systemctl is-active zramswap.service 2>/dev/null || true)"
for expected in ALGO=lz4 PERCENT=50 PRIORITY=100; do
    key="${expected%%=*}"
    wanted="${expected#*=}"
    current="$(awk -F= -v key="$key" '$1 == key { print $2 }' "$zram_config" 2>/dev/null || true)"
    printf '  zram %-8s %s (expected %s)\n' "$key" "${current:-unset}" "$wanted"
done
if sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null | grep -qx 0; then
    printf '  AppArmor   unprivileged user namespaces allowed\n'
else
    printf '  AppArmor   restricted; change only if a required application cannot start\n'
fi
trusted_users="$(nix show-config 2>/dev/null | awk -F= '$1 ~ /^trusted-users[[:space:]]*$/ { print $2 }' || true)"
if printf '%s\n' "$trusted_users" | tr ' ' '\n' | grep -Fxq "$workstation_user"; then
    printf '  Nix        %s is trusted\n' "$workstation_user"
else
    printf '  Nix        verify that %s is listed in trusted-users\n' "$workstation_user"
fi
for expected in accept_ra=2 accept_ra_rt_info_max_plen=128; do
    key="${expected%%=*}"
    wanted="${expected#*=}"
    current="$(sysctl -n "net.ipv6.conf.${main_interface}.${key}" 2>/dev/null || true)"
    printf '  IPv6 %-27s %s (expected %s)\n' "$key" "${current:-unset}" "$wanted"
done
ipv6_sysctl=/etc/sysctl.d/60-workstation-ipv6-ra.conf
ipv6_dispatcher=/etc/NetworkManager/dispatcher.d/90-workstation-ipv6-ra
if [[ -f "$ipv6_sysctl" ]]; then
    printf '  IPv6 sysctl persistence          installed\n'
else
    printf '  IPv6 sysctl persistence          missing\n'
fi
if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
    if [[ -x "$ipv6_dispatcher" ]]; then
        printf '  IPv6 NetworkManager persistence  installed\n'
    else
        printf '  IPv6 NetworkManager persistence  missing\n'
    fi
fi

printf '\nDevice rules:\n'
rule_status() {
    local source="$1"
    local destination="$2"
    if [[ -z "$source" ]]; then
        printf 'source not found\n'
    elif cmp -s "$source" "$destination"; then
        printf 'installed\n'
    elif [[ -e "$destination" ]]; then
        printf 'update available from %s\n' "$source"
    else
        printf 'available from %s\n' "$source"
    fi
}
printf '  Solaar     '
rule_status "$solaar_rules" /etc/udev/rules.d/42-logitech-unify-permissions.rules
printf '  OpenOCD    '
rule_status "$openocd_rules" /etc/udev/rules.d/60-openocd.rules

[[ "$mode" == --apply ]] || exit 0

cat <<'EOF'

Apply mode will install APT packages, configure zram to use 50% of RAM with
lz4 compression, configure IPv6 router advertisements on the selected primary
interface, add the user to dialout and plugdev, and install device rules that
were discovered above. It does not upgrade Ubuntu, install Docker, alter Nix
daemon trust, or relax AppArmor.
EOF
read -r -p "Type apply to continue: " confirmation </dev/tty
[[ "$confirmation" == apply ]] || {
    printf 'Cancelled.\n'
    exit 0
}

sudo -v
sudo apt-get update
sudo apt-get install --yes "${packages[@]}"

set_zram_value() {
    local key="$1"
    local value="$2"
    if sudo grep -qE "^[#[:space:]]*${key}=" "$zram_config"; then
        sudo sed -Ei "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$zram_config"
    else
        printf '%s=%s\n' "$key" "$value" | sudo tee -a "$zram_config" >/dev/null
    fi
}
set_zram_value ALGO lz4
set_zram_value PERCENT 50
set_zram_value PRIORITY 100
sudo systemctl enable --now zramswap.service
sudo systemctl restart zramswap.service

ipv6_sysctl=/etc/sysctl.d/60-workstation-ipv6-ra.conf
sudo tee "$ipv6_sysctl" >/dev/null <<EOF
# Accept router advertisements and route information on the primary uplink.
net.ipv6.conf.${main_interface}.accept_ra=2
net.ipv6.conf.${main_interface}.accept_ra_rt_info_max_plen=128
EOF
sudo sysctl --load "$ipv6_sysctl"

if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
    sudo install -d -m 0755 /etc/NetworkManager/dispatcher.d
    sudo tee "$ipv6_dispatcher" >/dev/null <<EOF
#!/bin/sh
# NetworkManager may override IPv6 sysctls whenever it activates a connection.
[ "\$1" = "${main_interface}" ] || exit 0
case "\$2" in
    up|dhcp6-change|reapply)
        /usr/sbin/sysctl -q -w net.ipv6.conf.${main_interface}.accept_ra=2
        /usr/sbin/sysctl -q -w net.ipv6.conf.${main_interface}.accept_ra_rt_info_max_plen=128
        ;;
esac
EOF
    sudo chmod 0755 "$ipv6_dispatcher"
fi

for group in "${groups[@]}"; do
    if getent group "$group" >/dev/null; then
        sudo usermod --append --groups "$group" "$workstation_user"
    fi
done

rules_changed=false
install_rule() {
    local source="$1"
    local destination="$2"
    if [[ -n "$source" ]] && ! cmp -s "$source" "$destination"; then
        sudo install -m 0644 "$source" "$destination"
        rules_changed=true
    fi
}
install_rule "$solaar_rules" /etc/udev/rules.d/42-logitech-unify-permissions.rules
install_rule "$openocd_rules" /etc/udev/rules.d/60-openocd.rules
if [[ "$rules_changed" == true ]]; then
    sudo udevadm control --reload-rules
fi

printf '\nUbuntu workstation prerequisites applied. Log out and back in for new group memberships.\n'
