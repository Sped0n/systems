#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"
[[ $# -eq 3 && -f "$1" && -f "$2" ]] || { echo "Usage: render-with-params.sh input.scad params.json output.stl|output.png" >&2; exit 1; }
input="$1"
params="$2"
output="$3"
mapfile -t defines < <(python3 - "$params" <<'PY'
import json
import sys
for name, value in json.load(open(sys.argv[1], encoding="utf-8")).items():
    if isinstance(value, bool): value = str(value).lower()
    elif isinstance(value, str): value = json.dumps(value)
    print(f"{name}={value}")
PY
)
check_openscad
mkdir -p "$(dirname "$output")"
arguments=()
for define in "${defines[@]}"; do
  arguments+=(-D "$define")
done
case "$output" in
  *.stl|*.STL) "$OPENSCAD" "${arguments[@]}" -o "$output" "$input" ;;
  *.png|*.PNG) "$OPENSCAD" "${arguments[@]}" --camera=0,0,0,55,0,25,0 --imgsize=800,600 --autocenter --viewall -o "$output" "$input" ;;
  *) echo "output must end in .stl or .png" >&2; exit 1 ;;
esac
printf 'Output saved: %s\n' "$output"
