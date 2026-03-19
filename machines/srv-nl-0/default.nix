{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./hm
    ./networking
    ./services

    ./disko.nix
    ./system.nix
  ];
}
