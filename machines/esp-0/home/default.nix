{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/home/nixos/desktop")

    ./programs

    ./gc.nix
    ./packages.nix
    ./ubuntu.nix
  ];
}
