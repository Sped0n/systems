#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"
[[ $# -ge 2 ]] || { echo "Usage: export-stl.sh input.scad output.stl [-D name=value]" >&2; exit 1; }
input="$1"
output="$2"
shift 2
[[ -f "$input" ]] || { echo "file not found: $input" >&2; exit 1; }
defines=()
while [[ $# -gt 0 ]]; do
  [[ "$1" == -D && $# -ge 2 ]] || { echo "expected -D name=value" >&2; exit 1; }
  defines+=(-D "$2")
  shift 2
done
check_openscad
mkdir -p "$(dirname "$output")"
"$OPENSCAD" "${defines[@]}" -o "$output" "$input"
printf 'STL exported: %s\n' "$output"
