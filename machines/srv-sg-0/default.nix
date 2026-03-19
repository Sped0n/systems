{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/server")

    ./hm
    ./services

    ./builder.nix
    ./disko.nix
    ./networking.nix
    ./system.nix
  ];
}
