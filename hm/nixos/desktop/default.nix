{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/nixos/shared")

    ./programs
    ./services

    ./packages.nix
  ];
}
