#!/usr/bin/env bash
set -euo pipefail

warn() {
  printf 'warning: %s\n' "$*" >&2
}

workstation_user=$(id -un)
if [[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || true)" == 1 ]]; then
  warn "AppArmor restricts unprivileged user namespaces. Only investigate if a required application cannot start."
  warn "  journalctl -k -g 'apparmor=\"DENIED\"'"
fi
# Client-side trusted-users does not establish whether the daemon trusts this user.
if daemon_info="$(nix --extra-experimental-features nix-command store ping --store daemon --json 2>/dev/null)"; then
  if grep -Eq '"trusted"[[:space:]]*:[[:space:]]*false' <<<"$daemon_info"; then
    warn "The Nix daemon does not trust $workstation_user; privileged cache settings may be ignored. Trust grants root-equivalent control."
    warn "  sudoedit /etc/nix/nix.conf  # add: extra-trusted-users = $workstation_user"
    warn "  sudo systemctl restart nix-daemon.service"
  elif ! grep -Eq '"trusted"[[:space:]]*:[[:space:]]*true' <<<"$daemon_info"; then
    warn "The Nix daemon did not report trust status; inspect it with: nix store ping --store daemon --json"
  fi
else
  warn "Could not query the Nix daemon; inspect it with: nix store ping --store daemon --json"
fi
