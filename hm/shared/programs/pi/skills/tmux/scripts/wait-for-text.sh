#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wait-for-text.sh [-S socket-path|-L socket-name] -t target -p pattern [options]

Options:
  -S, --socket-path  tmux socket path
  -L, --socket-name  tmux socket name
  -t, --target       tmux pane target (required)
  -p, --pattern      regex pattern to look for (required)
  -F, --fixed        treat the pattern as a fixed string
  -T, --timeout      seconds to wait (default: 15)
  -i, --interval     poll interval seconds (default: 0.5)
  -l, --lines        history lines to inspect (default: 1000)
EOF
}

socket_path=""
socket_name=""
target=""
pattern=""
grep_flag="-E"
timeout=15
interval=0.5
lines=1000

while [[ $# -gt 0 ]]; do
  case "$1" in
    -S|--socket-path) socket_path="${2-}"; shift 2 ;;
    -L|--socket-name) socket_name="${2-}"; shift 2 ;;
    -t|--target) target="${2-}"; shift 2 ;;
    -p|--pattern) pattern="${2-}"; shift 2 ;;
    -F|--fixed) grep_flag="-F"; shift ;;
    -T|--timeout) timeout="${2-}"; shift 2 ;;
    -i|--interval) interval="${2-}"; shift 2 ;;
    -l|--lines) lines="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$target" && -n "$pattern" ]] || { echo "target and pattern are required" >&2; exit 1; }
[[ -z "$socket_path" || -z "$socket_name" ]] || { echo "use either -S or -L, not both" >&2; exit 1; }
[[ "$timeout" =~ ^[0-9]+$ && "$lines" =~ ^[0-9]+$ ]] || { echo "timeout and lines must be integers" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "tmux not found in PATH" >&2; exit 1; }

tmux_cmd=(tmux)
if [[ -n "$socket_path" ]]; then tmux_cmd+=(-S "$socket_path"); fi
if [[ -n "$socket_name" ]]; then tmux_cmd+=(-L "$socket_name"); fi

deadline=$(( $(date +%s) + timeout ))
while true; do
  pane_text="$("${tmux_cmd[@]}" capture-pane -p -J -t "$target" -S "-$lines" 2>/dev/null || true)"
  if printf '%s\n' "$pane_text" | grep "$grep_flag" -- "$pattern" >/dev/null 2>&1; then exit 0; fi
  if (( $(date +%s) >= deadline )); then
    printf 'timed out after %ss waiting for %s\n%s\n' "$timeout" "$pattern" "$pane_text" >&2
    exit 1
  fi
  sleep "$interval"
done
