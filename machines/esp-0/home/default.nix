{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/home/nixos/desktop")

    ./programs

    ./packages.nix
    ./ubuntu.nix
  ];
}
