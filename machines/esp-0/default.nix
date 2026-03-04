{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/desktop")

    ./home
    ./services
    ./system

    ./disko.nix
    ./networking.nix
    ./programs.nix
  ];
}
