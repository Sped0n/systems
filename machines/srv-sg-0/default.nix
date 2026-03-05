{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./home
    ./services

    ./builder.nix
    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
