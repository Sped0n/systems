{ config, lib, pkgs, ... }:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  inherit (common) enabledArches keyPath;
in
{
  config = lib.mkIf cfg.enable {
    nix.distributedBuilds = true;
    nix.settings.builders-use-substitutes = true;
    nix.buildMachines = lib.mapAttrsToList (_: arch: {
      hostName = arch.name;
      protocol = "ssh-ng";
      sshUser = "root";
      sshKey = keyPath;
      systems = arch.systems;
      inherit (arch) maxJobs;
      speedFactor = 1;
      supportedFeatures = [ "big-parallel" ];
    }) enabledArches;
  };
}
