{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/home/nixos/shared")

    ./programs
    ./services

    ./packages.nix
  ];
}
