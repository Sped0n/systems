#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: find-sessions.sh [-L socket-name|-S socket-path|--all] [-q pattern]
EOF
}

socket_name=""
socket_path=""
query=""
all=0
socket_dir="${PI_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/pi-tmux-sockets}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -L|--socket-name) socket_name="${2-}"; shift 2 ;;
    -S|--socket-path) socket_path="${2-}"; shift 2 ;;
    -A|--all) all=1; shift ;;
    -q|--query) query="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[[ -z "$socket_name" || -z "$socket_path" ]] || { echo "use either -S or -L, not both" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "tmux not found in PATH" >&2; exit 1; }

list_sessions() {
  local label="$1"
  shift
  local sessions
  if ! sessions="$(tmux "$@" list-sessions -F '#{session_name}\t#{session_attached}\t#{session_created_string}' 2>/dev/null)"; then
    printf 'no tmux server found on %s\n' "$label" >&2
    return 1
  fi
  [[ -z "$query" ]] || sessions="$(printf '%s\n' "$sessions" | grep -i -- "$query" || true)"
  [[ -n "$sessions" ]] || { printf 'no sessions found on %s\n' "$label"; return 0; }
  printf 'sessions on %s:\n%s\n' "$label" "$sessions"
}

if (( all )); then
  [[ -d "$socket_dir" ]] || { echo "socket directory not found: $socket_dir" >&2; exit 1; }
  shopt -s nullglob
  sockets=("$socket_dir"/*)
  shopt -u nullglob
  for socket in "${sockets[@]}"; do [[ -S "$socket" ]] && list_sessions "socket path '$socket'" -S "$socket"; done
elif [[ -n "$socket_name" ]]; then
  list_sessions "socket name '$socket_name'" -L "$socket_name"
else
  socket_path="${socket_path:-$socket_dir/pi.sock}"
  list_sessions "socket path '$socket_path'" -S "$socket_path"
fi
