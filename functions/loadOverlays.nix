{
  overlayDirectory,
  args ? { },
}:
let
  inherit (builtins)
    attrNames
    filter
    functionArgs
    isFunction
    match
    pathExists
    readDir
    ;

  directoryNames = attrNames (readDir overlayDirectory);

  isNixFile = entryName: match ".*\\.nix" entryName != null;
  hasDefaultFile = entryName: pathExists (overlayDirectory + ("/" + entryName + "/default.nix"));

  importOverlay =
    entryName:
    let
      v = import (overlayDirectory + ("/" + entryName));
    in
    if isFunction v then
      # If it's already an overlay (takes `final`), keep it.
      if (functionArgs v) ? final then v else v args
    else
      v;
in
map importOverlay (
  filter (entryName: isNixFile entryName || hasDefaultFile entryName) directoryNames
)
