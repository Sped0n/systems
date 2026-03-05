{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./home
    ./services

    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
