#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.

prepare() {
    main_interface=""
    local interface_explicit=false
    if (($# > 0)); then
        [[ $# == 2 && "$1" == --interface ]] || usage
        main_interface="$2"
        interface_explicit=true
    fi
    if [[ "$interface_explicit" == false ]]; then
        main_interface="$(
            ip -6 route show default 2>/dev/null |
                awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true
        )"
        if [[ -z "$main_interface" ]]; then
            main_interface="$(
                ip route show default 2>/dev/null |
                    awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true
            )"
        fi
    fi
    if [[ ! "$main_interface" =~ ^[A-Za-z0-9_.:-]+$ || ! -d "/sys/class/net/$main_interface" ]]; then
        if [[ "$mode" == --check && "$interface_explicit" == false ]]; then
            if [[ -z "$main_interface" ]]; then
                warn 'No default-route interface found; IPv6 checks skipped.'
            else
                warn "Inferred interface $main_interface is unavailable or unsupported; IPv6 checks skipped."
            fi
            warn 'To check an uplink manually, replace INTERFACE in:'
            printf '  %q --check --interface INTERFACE\n' "$0" >&2
            exit 0
        fi
        printf 'error: Could not resolve network interface %s; pass --interface <name>.\n' "${main_interface:-<none>}" >&2
        exit 1
    fi
    setup_args=(--interface "$main_interface")
    ipv6_sysctl=/etc/sysctl.d/60-workstation-ipv6-ra.conf
    ipv6_dispatcher=/etc/NetworkManager/dispatcher.d/90-workstation-ipv6-ra
    ipv6_sysctl_content="$(
        cat <<EOF
# Accept router advertisements and route information on the primary uplink.
net/ipv6/conf/${main_interface}/accept_ra=2
net/ipv6/conf/${main_interface}/accept_ra_rt_info_max_plen=128
EOF
    )"
    ipv6_dispatcher_content="$(
        cat <<EOF
#!/bin/sh
# NetworkManager may override IPv6 sysctls whenever it activates a connection.
[ "\$1" = "${main_interface}" ] || exit 0
case "\$2" in
    up|dhcp6-change|reapply)
        /usr/sbin/sysctl -q -w net/ipv6/conf/${main_interface}/accept_ra=2
        /usr/sbin/sysctl -q -w net/ipv6/conf/${main_interface}/accept_ra_rt_info_max_plen=128
        ;;
esac
EOF
    )"
    if [[ "$mode" == --apply ]]; then
        printf 'Selected uplink: %s\n' "$main_interface"
    fi
}

check() {
    for expected in accept_ra=2 accept_ra_rt_info_max_plen=128; do
        key="${expected%%=*}"
        wanted="${expected#*=}"
        current="$(sysctl -n "net/ipv6/conf/${main_interface}/${key}" 2>/dev/null || true)"
        if [[ "$current" != "$wanted" ]]; then
            mismatch "$main_interface: IPv6 $key is ${current:-unset}, expected $wanted."
        fi
    done
    if [[ ! -r "$ipv6_sysctl" ]] || [[ "$(<"$ipv6_sysctl")" != "$ipv6_sysctl_content" ]]; then
        mismatch "$ipv6_sysctl is missing or outdated for $main_interface."
    fi
    if systemctl is-active --quiet NetworkManager.service; then
        if [[ ! -r "$ipv6_dispatcher" || ! -x "$ipv6_dispatcher" ]] || [[ "$(<"$ipv6_dispatcher")" != "$ipv6_dispatcher_content" ]]; then
            mismatch "$ipv6_dispatcher is missing or outdated for $main_interface."
        fi
    fi
}

apply() {
    printf '%s\n' "$ipv6_sysctl_content" | sudo tee "$ipv6_sysctl" >/dev/null
    sudo sysctl --load "$ipv6_sysctl"
    if systemctl is-active --quiet NetworkManager.service; then
        sudo install -d -m 0755 /etc/NetworkManager/dispatcher.d
        printf '%s\n' "$ipv6_dispatcher_content" | sudo tee "$ipv6_dispatcher" >/dev/null
        sudo chmod 0755 "$ipv6_dispatcher"
    fi
}
