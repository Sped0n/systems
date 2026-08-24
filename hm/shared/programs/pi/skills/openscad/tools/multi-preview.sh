#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"
[[ $# -ge 2 ]] || { echo "Usage: multi-preview.sh input.scad output-dir [-D name=value]" >&2; exit 1; }
input="$1"
output_dir="$2"
shift 2
[[ -f "$input" ]] || { echo "file not found: $input" >&2; exit 1; }
defines=()
while [[ $# -gt 0 ]]; do
  [[ "$1" == -D && $# -ge 2 ]] || { echo "expected -D name=value" >&2; exit 1; }
  defines+=(-D "$2")
  shift 2
done
check_openscad
mkdir -p "$output_dir"
base="$(basename "$input" .scad)"
while IFS=: read -r angle camera; do
  output="$output_dir/${base}_${angle}.png"
  "$OPENSCAD" --camera="$camera" --imgsize=800,600 --colorscheme="Tomorrow Night" --autocenter --viewall "${defines[@]}" -o "$output" "$input"
  printf 'Preview saved: %s\n' "$output"
done <<'EOF'
iso:0,0,0,55,0,25,0
front:0,0,0,90,0,0,0
back:0,0,0,90,0,180,0
left:0,0,0,90,0,90,0
right:0,0,0,90,0,-90,0
top:0,0,0,0,0,0,0
EOF
