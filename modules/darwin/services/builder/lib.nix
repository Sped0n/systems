{ config, lib, pkgs }:
let
  cfg = config.services.my-linux-builder;
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home or "/Users/${user}";
  containerBin = lib.getExe pkgs.apple-container;

  arches = {
    aarch64-linux = {
      name = "darwin-builder-aarch64";
      port = 31022;
      systems = [ "aarch64-linux" ];
      platformArgs = [ ];
      maxJobs = cfg.maxJobs;
    };
    x86_64-linux = {
      name = "darwin-builder-x86_64";
      port = 31023;
      systems = [ "x86_64-linux" ];
      platformArgs = [
        "--platform"
        "linux/amd64"
      ];
      maxJobs = cfg.maxJobs;
    };
  };

  mkPlist = label: serviceConfig:
    pkgs.writeText "${label}.plist" (lib.generators.toPlist { escape = true; } serviceConfig);
in
rec {
  inherit
    containerBin
    mkPlist
    user
    userHome
    ;

  enabledArches = arches;

  appSupport = "${userHome}/Library/Application Support/com.apple.container";
  launchAgentsDir = "/Library/LaunchAgents";
  runtimeLabel = "my-linux-builder.runtime";
  stateDir = "/tmp/my-linux-builder";
  keyPath = "${userHome}/.ssh/darwin-builder_ed25519";
  pubKeyPath = "${keyPath}.pub";
  runAsUser = "sudo -u ${user} --";
}
