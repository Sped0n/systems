{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/server")

    ./home
    ./networking
    ./services

    ./disko.nix
    ./system.nix
  ];
}
