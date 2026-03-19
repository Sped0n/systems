{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/nixos/desktop")

    ./programs

    ./packages.nix
    ./ubuntu.nix
  ];
}
