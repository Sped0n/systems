#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.

prepare() {
    (($# == 0)) || usage
    zram_settings=(ALGO=lz4 PERCENT=50 PRIORITY=100)
    zram_config=/etc/default/zramswap
    if ! dpkg-query -W -f='${db:Status-Abbrev}' zram-tools 2>/dev/null | grep -q '^ii '; then
        if [[ "$mode" == --check ]]; then
            warn 'zram-tools is missing; zram checks are deferred until the package setup command has been run.'
            exit 0
        fi
        printf 'error: Install zram-tools with the package setup command first.\n' >&2
        exit 1
    fi
}

check() {
    if ! systemctl is-active --quiet zramswap.service; then
        mismatch 'zramswap.service is not active.'
    fi
    if ! systemctl is-enabled --quiet zramswap.service 2>/dev/null; then
        mismatch 'zramswap.service is not enabled.'
    fi
    for expected in "${zram_settings[@]}"; do
        key="${expected%%=*}"
        wanted="${expected#*=}"
        current="$(awk -F= -v key="$key" '
            $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
                value = $2
                sub(/[[:space:]]*#.*/, "", value)
                gsub(/^[[:space:]"\047]+|[[:space:]"\047]+$/, "", value)
            }
            END { print value }
        ' "$zram_config" 2>/dev/null || true)"
        if [[ "$current" != "$wanted" ]]; then
            mismatch "$zram_config: $key is ${current:-unset}, expected $wanted."
        fi
    done
}

apply() {
    set_zram_value() {
        local key="$1"
        local value="$2"
        if sudo grep -qE "^[#[:space:]]*${key}=" "$zram_config"; then
            sudo sed -Ei "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$zram_config"
        else
            printf '%s=%s\n' "$key" "$value" | sudo tee -a "$zram_config" >/dev/null
        fi
    }
    for expected in "${zram_settings[@]}"; do
        set_zram_value "${expected%%=*}" "${expected#*=}"
    done
    sudo systemctl enable --now zramswap.service
    sudo systemctl restart zramswap.service
}
