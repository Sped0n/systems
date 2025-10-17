{
  lib,
  pkgs-unstable,
  ...
}:
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

  environment.systemPackages = [
    pkgs-unstable.nixos-rebuild-ng
  ];
}
