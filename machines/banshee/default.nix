{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./home
    ./networking
    ./services

    ./builder.nix
    ./disko.nix
    ./system.nix
  ];

}
