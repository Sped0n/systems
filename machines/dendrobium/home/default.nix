{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/home/darwin")

    ./programs
    ./packages.nix
  ];
}
