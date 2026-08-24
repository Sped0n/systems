#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 && $# -le 2 && -f "$1" ]] || { echo "Usage: extract-params.sh input.scad [--json]" >&2; exit 1; }
input="$1"
json="${2:-}"
[[ -z "$json" || "$json" == --json ]] || { echo "unknown option: $json" >&2; exit 1; }
python3 - "$input" "$json" <<'PY'
import json
import re
import sys

parameters = []
depth = 0
for line in open(sys.argv[1], encoding="utf-8"):
    depth += line.count("{") - line.count("}")
    match = re.match(r"^\s*([A-Za-z_]\w*)\s*=\s*([^;]+);\s*(?://\s*(.*))?", line)
    if depth == 0 and match:
        parameters.append({"name": match.group(1), "value": match.group(2).strip(), "description": match.group(3) or ""})
if sys.argv[2] == "--json":
    print(json.dumps(parameters, indent=2))
else:
    for parameter in parameters:
        print("{name} = {value}\t{description}".format(**parameter))
PY
