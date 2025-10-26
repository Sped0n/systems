{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/shared")

    ./services

    ./agenix.nix
  ];
}
