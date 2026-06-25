{
  pkgs ? import (builtins.getFlake "nixpkgs") {
    system = builtins.currentSystem;
  },
}:

let
  packageFiles = pkgs.lib.filterAttrs (
    name: type: type == "regular" && name != "default.nix" && pkgs.lib.hasSuffix ".nix" name
  ) (builtins.readDir ./.);
in
pkgs.lib.mapAttrs' (
  name: _:
  pkgs.lib.nameValuePair (pkgs.lib.removeSuffix ".nix" name) (pkgs.callPackage (./. + "/${name}") { })
) packageFiles
