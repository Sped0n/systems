{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/server")

    ./home
    ./networking
    ./services

    ./builder.nix
    ./disko.nix
    ./system.nix
  ];

}
