{ config, lib, pkgs }:
let
  cfg = config.services.my-linux-builder;
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home or "/Users/${user}";
  containerBin = lib.getExe pkgs.apple-container;

  builder = {
    name = "darwin-builder";
    port = 31022;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    runArgs = [
      "--cap-add"
      "SYS_ADMIN"
    ];
    maxJobs = cfg.maxJobs;
  };

  mkPlist = label: serviceConfig:
    pkgs.writeText "${label}.plist" (lib.generators.toPlist { escape = true; } serviceConfig);
in
rec {
  inherit
    containerBin
    builder
    mkPlist
    user
    userHome
    ;

  appSupport = "${userHome}/Library/Application Support/com.apple.container";
  launchAgentsDir = "/Library/LaunchAgents";
  runtimeLabel = "my-linux-builder.runtime";
  stateDir = "/tmp/my-linux-builder";
  keyPath = "${userHome}/.ssh/darwin-builder_ed25519";
  pubKeyPath = "${keyPath}.pub";
  runAsUser = "sudo -u ${user} --";
}
