{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/desktop")

    ./home
    ./services
    ./system

    ./age.nix
    ./disko.nix
    ./networking.nix
  ];
}
