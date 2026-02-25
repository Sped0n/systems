{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/home/nixos/shared")

    ./programs

    ./packages.nix
  ];
}
