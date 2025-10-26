{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/home/shared")

    ./packages.nix
    ./programs
  ];
}
