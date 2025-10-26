overlayDirectory:
let
  inherit (builtins)
    attrNames
    filter
    map
    match
    pathExists
    readDir
    ;

  directoryNames = attrNames (readDir overlayDirectory);

  isNixFile = entryName: match ".*\\.nix" entryName != null;

  hasDefaultFile = entryName: pathExists (overlayDirectory + ("/" + entryName + "/default.nix"));

  importOverlay = entryName: import (overlayDirectory + ("/" + entryName));
in
map importOverlay (
  filter (entryName: isNixFile entryName || hasDefaultFile entryName) directoryNames
)
