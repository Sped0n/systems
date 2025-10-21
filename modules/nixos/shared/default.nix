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

  # system wide gc
  nix.gc = {
    automatic = true;
    dates = lib.mkDefault "daily";
    options = lib.mkDefault "--delete-older-than 21d";
  };

  # user profile gc
  systemd.user.services."nix-gc" = {
    description = "Garbage collection for user profiles";
    script = "/run/current-system/sw/bin/nix-collect-garbage --delete-older-than 21d";
    startAt = "daily";
  };

  environment.systemPackages = [
    pkgs-unstable.nixos-rebuild-ng
  ];
}
