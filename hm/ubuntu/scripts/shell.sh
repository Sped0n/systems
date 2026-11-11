#!/usr/bin/env bash
# Embedded by setup-script.nix; the shared runner invokes these functions.
prepare() {
    (($# == 0)) || usage
    if [[ "$workstation_user" != "$shell_user" ]]; then
        printf 'error: Run this script as %s.\n' "$shell_user" >&2
        exit 1
    fi
    if [[ ! -x "$shell_path" ]]; then
        printf 'error: Home Manager shell is not executable: %s\n' "$shell_path" >&2
        exit 1
    fi
    user_entry=$(getent passwd "$workstation_user")
    current_shell=${user_entry##*:}
}

check() {
    if ! grep -Fxq -- "$shell_path" /etc/shells; then
        mismatch "Home Manager Zsh is not registered in /etc/shells: $shell_path"
    fi
    if [[ "$current_shell" != "$shell_path" ]]; then
        mismatch "The login shell for $workstation_user is $current_shell, not $shell_path."
    fi
}

apply() {
    if ! grep -Fxq -- "$shell_path" /etc/shells; then
        printf '\n%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
    fi
    if [[ "$current_shell" != "$shell_path" ]]; then
        sudo chsh -s "$shell_path" "$workstation_user"
        printf 'Login shell updated. Log out and back in to use it.\n'
    fi
}
