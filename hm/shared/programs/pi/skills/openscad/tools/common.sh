#!/usr/bin/env bash

find_openscad() {
  if command -v openscad >/dev/null 2>&1; then command -v openscad; return; fi
  if [[ -x /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD ]]; then
    printf '%s\n' /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD
    return
  fi
  return 1
}

check_openscad() {
  OPENSCAD="$(find_openscad)" || { echo "OpenSCAD not found on PATH" >&2; exit 1; }
  export OPENSCAD
}
