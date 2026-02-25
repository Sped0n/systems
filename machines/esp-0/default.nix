{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/desktop")

    ./home
    ./services

    ./age.nix
    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
