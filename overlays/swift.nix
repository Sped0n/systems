# see https://github.com/NixOS/nixpkgs/issues/483584
{ inputs, ... }:
final: prev:
let
  system = prev.stdenv.system;
  pkgs-swift = inputs.nixpkgs-swift.legacyPackages.${system};
in
{
  swift = pkgs-swift.swift;
  swiftPackages = pkgs-swift.swiftPackages;
}
// prev.lib.optionalAttrs (builtins.match ".*darwin$" system != null) {
  # Marksman relies on dotnet
  # NOTE: dirty hack here, since dotnetCorePackages took ages to build on my laptop
  dotnetCorePackages = pkgs-swift.dotnetCorePackages;
}
