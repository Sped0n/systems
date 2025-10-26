{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/home/nixos/shared")

    ./programs

    ./packages.nix
  ];
}
