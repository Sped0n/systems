#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"
[[ $# -eq 1 && -f "$1" ]] || { echo "Usage: validate.sh input.scad" >&2; exit 1; }
check_openscad
output="$(mktemp "${TMPDIR:-/tmp}/openscad-validate.XXXXXX.echo")"
trap 'rm -f "$output"' EXIT
"$OPENSCAD" --export-format=echo -o "$output" "$1"
printf 'Syntax OK: %s\n' "$1"
[[ ! -s "$output" ]] || cat "$output"
