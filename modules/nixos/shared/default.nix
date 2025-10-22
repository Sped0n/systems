{
  config,
  lib,
  pkgs-unstable,
  ...
}:
{
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./docker.nix
    ./networking
  ];

  # system wide gc
  nix.gc = {
    automatic = true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 21d";
  };

  # user profile gc
  systemd.user.services."nix-gc" = {
    description = "Garbage collection for user profiles";
    script = "/run/current-system/sw/bin/nix-collect-garbage ${config.nix.gc.options}";
    startAt = config.nix.gc.dates;
  };

  environment.systemPackages = [
    pkgs-unstable.nixos-rebuild-ng
  ];
}
