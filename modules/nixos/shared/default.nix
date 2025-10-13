{ lib, ... }:
{
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./networking.nix
    ./docker.nix
  ];

  nix.gc = {
    automatic = true;
    dates = lib.mkDefault "daily";
    options = lib.mkDefault "--delete-older-than 21d";
  };
}
