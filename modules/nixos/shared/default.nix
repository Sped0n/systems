{ pkgs-unstable, libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/shared")

    ./networking

    ./diff.nix
    ./docker.nix
    ./gc.nix
    ./system.nix
    ./users.nix
  ];

  environment.systemPackages = [
    pkgs-unstable.nixos-rebuild-ng
  ];
}
