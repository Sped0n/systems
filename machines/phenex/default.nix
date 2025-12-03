{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./home
    ./networking
    ./services

    ./disko.nix
    ./system.nix
  ];
}
