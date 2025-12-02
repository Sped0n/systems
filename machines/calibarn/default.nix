{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/server")

    ./home
    ./services

    ./builder.nix
    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
