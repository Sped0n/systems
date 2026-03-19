{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/nixos/shared")

    ./programs

    ./packages.nix
  ];
}
