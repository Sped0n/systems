{ config, lib, pkgs, ... }:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  inherit (common) builder keyPath;
in
{
  config = lib.mkIf cfg.enable {
    nix.distributedBuilds = true;
    nix.settings.builders-use-substitutes = true;
    nix.buildMachines = [ {
      hostName = builder.name;
      protocol = "ssh-ng";
      sshUser = "root";
      sshKey = keyPath;
      systems = builder.systems;
      inherit (builder) maxJobs;
      speedFactor = 1;
      supportedFeatures = [ "big-parallel" ];
    } ];
  };
}
