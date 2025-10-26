{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/home/nixos/server")

    ./programs
    ./packages.nix
  ];
}
