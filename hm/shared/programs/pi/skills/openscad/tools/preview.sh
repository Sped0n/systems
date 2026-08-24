#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"
[[ $# -ge 2 ]] || { echo "Usage: preview.sh input.scad output.png [--camera=x,y,z,rx,ry,rz,distance] [--size=WxH] [-D name=value]" >&2; exit 1; }
input="$1"
output="$2"
shift 2
[[ -f "$input" ]] || { echo "file not found: $input" >&2; exit 1; }
camera="0,0,0,55,0,25,0"
size="800,600"
defines=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --camera=*) camera="${1#--camera=}" ;;
    --size=*) size="${1#--size=}"; size="${size/x/,}" ;;
    -D) [[ $# -ge 2 ]] || { echo "-D requires a value" >&2; exit 1; }; defines+=(-D "$2"); shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done
check_openscad
mkdir -p "$(dirname "$output")"
"$OPENSCAD" --camera="$camera" --imgsize="$size" --colorscheme="Tomorrow Night" --autocenter --viewall "${defines[@]}" -o "$output" "$input"
printf 'Preview saved: %s\n' "$output"
