{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  relay = config.services.my-ladder.relay;
in
{
  options.services.my-ladder.relay = {
    enable = lib.mkEnableOption "ladder relay node";
    exits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "1.2.3.4"
        "5.6.7.8"
      ];
      description = "Exit node IPs. First is preferred; later entries are fallbacks.";
    };
  };

  config = lib.mkIf relay.enable {
    assertions = [
      {
        assertion = relay.exits != [ ];
        message = "services.my-ladder.relay.exits must contain at least one exit IP.";
      }
      {
        assertion = !config.services.my-ladder.exit.enable;
        message = "services.my-ladder.relay and services.my-ladder.exit cannot both be enabled.";
      }
    ];

    networking.firewall = {
      allowedTCPPorts = [
        vars.ladderPorts.anytls
        vars.ladderPorts.snell
      ];
      allowedUDPPorts = [ vars.ladderPorts.snell ];
    };

    systemd.services.ladder = {
      description = "Ladder relay node";
      serviceConfig = {
        ExecStart = "${
          pkgs.writeShellApplication {
            name = "ladder-relay-manager";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              export LADDER_MANAGER_CONFIG=${
                pkgs.writeText "ladder-relay-manager-config.json" (
                  builtins.toJSON {
                    role = "relay";
                    stateDir = "/var/lib/ladder";
                    certPath = "/var/lib/ladder/disguise.crt";
                    keyPath = "/var/lib/ladder/disguise.key";
                    singboxConfigPath = "/var/lib/ladder/sing-box.json";
                    snellConfigPath = "/var/lib/ladder/snell-server.conf";
                    passwordFile = config.age.secrets."ladder-password".path;
                    exits = relay.exits;
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
        }/bin/ladder-relay-manager";
      };
    };
  };
}
