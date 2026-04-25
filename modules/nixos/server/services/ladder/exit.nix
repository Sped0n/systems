{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  exit = config.services.my-ladder.exit;
in
{
  options.services.my-ladder.exit = {
    enable = lib.mkEnableOption "ladder exit node";
  };

  config = lib.mkIf exit.enable {
    assertions = [
      {
        assertion = !config.services.my-ladder.relay.enable;
        message = "services.my-ladder.exit and services.my-ladder.relay cannot both be enabled.";
      }
    ];

    networking.firewall = {
      allowedTCPPorts = [
        vars.ladderPorts.anytls
        vars.ladderPorts.ss2022
        vars.ladderPorts.snell
      ];
      allowedUDPPorts = [
        vars.ladderPorts.ss2022
        vars.ladderPorts.snell
      ];
    };

    systemd.services.ladder = {
      description = "Ladder exit node";
      serviceConfig = {
        ExecStart = "${
          pkgs.writeShellApplication {
            name = "ladder-exit-manager";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              export LADDER_MANAGER_CONFIG=${
                pkgs.writeText "ladder-exit-manager-config.json" (
                  builtins.toJSON {
                    role = "exit";
                    stateDir = "/var/lib/ladder";
                    certPath = "/var/lib/ladder/disguise.crt";
                    keyPath = "/var/lib/ladder/disguise.key";
                    singboxConfigPath = "/var/lib/ladder/sing-box.json";
                    snellConfigPath = "/var/lib/ladder/snell-server.conf";
                    passwordFile = config.age.secrets."ladder-password".path;
                    exits = [ ];
                    ports = { inherit (vars.ladderPorts) anytls ss2022 snell; };
                    commands = {
                      singBox = "${pkgs-unstable.sing-box}/bin/sing-box";
                      snellServer = "${pkgs-unstable.snell}/bin/snell-server";
                      ip = "${pkgs.iproute2}/bin/ip";
                      openssl = "${pkgs.openssl}/bin/openssl";
                      ping = "${pkgs.iputils}/bin/ping";
                    };
                  }
                )
              }
              exec python3 ${./manager.py}
            '';
          }
        }/bin/ladder-exit-manager";
      };
    };
  };
}
