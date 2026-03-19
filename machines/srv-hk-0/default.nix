{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./hm
    ./services

    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
