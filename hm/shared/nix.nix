{
  lib,
  nixpkgs,
  nixpkgs-unstable,
  pkgs,
  ...
}:
{
  nix.package = lib.mkDefault pkgs.nix;

  nix.registry = {
    nixpkgs.flake = nixpkgs;
    unstable.flake = nixpkgs-unstable;
  };
}
