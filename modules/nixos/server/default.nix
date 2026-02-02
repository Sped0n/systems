{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/shared")

    ./networking
    ./services

    ./headless.nix
  ];
}
