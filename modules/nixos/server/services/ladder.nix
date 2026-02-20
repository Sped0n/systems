{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  secrets,
  ...
}:
let
  my-ladder = config.services.my-ladder;
  singboxConfigPath = config.age.secrets."ladder-singbox-config".path;
  snellConfigPath = config.age.secrets."ladder-snell-config".path;

  stateDir = "/var/lib/ladder";
  keyPath = "${stateDir}/disguise.key";
  certPath = "${stateDir}/disguise.crt";
in
{
  options.services.my-ladder = {
    singbox = {
      enable = lib.mkEnableOption "Whether to enable sing-box proxy service";
      variant = lib.mkOption {
        type = lib.types.str;
        default = "default";
        example = "test";
        description = ''
          Which sing-box config variant to use.
          Reads config from:
          secrets/ages/ladder-singbox-config-<variant>.age
        '';
      };
      firewall = {
        tcpPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          example = [ 443 ];
          description = "TCP ports to open in the firewall for sing-box.";
        };
        udpPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          example = [ 443 ];
          description = "UDP ports to open in the firewall for sing-box.";
        };
      };
    };

    snell = {
      enable = lib.mkEnableOption "Whether to enable Snell proxy service";
      firewall = {
        tcpPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          example = [ 443 ];
          description = "TCP ports to open in the firewall for sing-box.";
        };
        udpPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          example = [ 443 ];
          description = "UDP ports to open in the firewall for sing-box.";
        };
      };
    };
  };

  config = lib.mkIf (my-ladder.singbox.enable || my-ladder.snell.enable) (
    let
      serviceConfigShared = {
        Type = "simple";
        User = "ladder";
        Group = "ladder";

        StateDirectory = "ladder";
        StateDirectoryMode = "0700";
        UMask = "0077";

        LimitNOFILE = 262144;
        TasksMax = "infinity";

        Restart = "on-failure";
        RestartSec = 3;

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;

        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        PrivateDevices = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      };
    in
    lib.mkMerge [
      {
        users = {
          users.ladder = {
            isSystemUser = true;
            group = "ladder";
          };
          groups.ladder = { };
        };

        boot.kernel.sysctl = {
          "net.ipv4.tcp_keepalive_time" = 300;
          "net.ipv4.tcp_keepalive_intvl" = 30;
          "net.ipv4.tcp_keepalive_probes" = 3;
          "net.ipv4.tcp_tw_reuse" = 1;
        };

        networking.firewall = {
          allowedTCPPorts = my-ladder.singbox.firewall.tcpPorts ++ my-ladder.snell.firewall.tcpPorts;
          allowedUDPPorts = my-ladder.singbox.firewall.udpPorts ++ my-ladder.snell.firewall.udpPorts;
        };
      }

      (lib.mkIf my-ladder.singbox.enable {
        age.secrets."ladder-singbox-config" = {
          file = "${secrets}/ages/ladder-singbox-config-${my-ladder.singbox.variant}.age";
          owner = "ladder";
          group = "ladder";
          mode = "0400";
        };

        systemd = {
          services = {
            ladder-singbox = {
              description = "Ladder sing-box service";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStartPre = [
                  (pkgs.writeShellScript "ladder-init" ''
                    set -euo pipefail
                    umask 077

                    install -d -m 700 "${stateDir}"

                    disguise="cname.vercel-dns.com"

                    generate_cert() {
                      echo "ladder: generating self-signed certificate for ''${disguise}..." >&2
                      rm -f "${keyPath}" "${certPath}"
                      ${pkgs.openssl}/bin/openssl req -x509 \
                        -newkey ec:<(${pkgs.openssl}/bin/openssl ecparam -name prime256v1) \
                        -keyout "${keyPath}" \
                        -out "${certPath}" \
                        -days 36500 \
                        -nodes \
                        -subj "/CN=''${disguise}"

                      chmod 400 "${keyPath}"
                      chmod 444 "${certPath}"
                    }

                    if [ ! -f "${keyPath}" ] || [ ! -f "${certPath}" ]; then
                      generate_cert
                    else
                      cert_cn="$(${pkgs.openssl}/bin/openssl x509 -in "${certPath}" -noout -subject | sed -n 's/.*CN=//p' | head -n1)"
                      if [ "''${cert_cn}" != "''${disguise}" ]; then
                        echo "ladder: certificate CN (''${cert_cn:-<none>}) does not match disguise (''${disguise}), regenerating..." >&2
                        generate_cert
                      fi
                    fi

                    echo "ladder: certificate SHA256 fingerprint:"
                    ${pkgs.openssl}/bin/openssl x509 -noout -fingerprint -sha256 -inform pem -in "${certPath}"
                  '')
                ];
                ExecStart = ''
                  ${pkgs-unstable.sing-box}/bin/sing-box run -c ${singboxConfigPath}
                '';
              }
              // serviceConfigShared;
            };

            ladder-singbox-config-watch = {
              description = "Restart ladder-singbox only when config content changes";
              after = [ "ladder-singbox.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "ladder-singbox-config-watch" ''
                  set -euo pipefail
                  file='${singboxConfigPath}'
                  state='${stateDir}/singbox-config.sha256'
                  [[ -r "$file" ]] || exit 0
                  new="$(${pkgs.coreutils}/bin/sha256sum "$file" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
                  old="$(${pkgs.coreutils}/bin/cat "$state" 2>/dev/null || true)"
                  if [[ "$new" != "$old" ]]; then
                    ${pkgs.coreutils}/bin/install -d -m 700 '${stateDir}'
                    printf '%s\n' "$new" > "$state"
                    /run/current-system/sw/bin/systemctl try-restart ladder-singbox.service
                  fi
                '';
              };
            };
          };

          paths.ladder-singbox-config = {
            wantedBy = [ "multi-user.target" ];
            pathConfig = {
              PathChanged = singboxConfigPath;
              Unit = "ladder-singbox-config-watch.service";
            };
          };
        };

        services.fail2ban.jails.singbox = {
          filter.Definition.failregex =
            "^.*process connection from <HOST>:\\d+: "
            + "(unknown user password"
            + "|TLS handshake: tls:"
            + "|TLS handshake: remote error:)";
          settings = {
            backend = "systemd";
            journalmatch = "_SYSTEMD_UNIT=ladder-singbox.service";
            findtime = "6h";
          };
        };
      })

      (lib.mkIf my-ladder.snell.enable {
        age.secrets."ladder-snell-config" = {
          file = "${secrets}/ages/ladder-snell-config.age";
          owner = "ladder";
          group = "ladder";
          mode = "0400";
        };

        systemd = {
          services = {
            ladder-snell = {
              description = "Ladder snell service";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              restartTriggers = [ ];
              serviceConfig = {
                ExecStart = ''
                  ${pkgs-unstable.snell}/bin/snell-server -c ${snellConfigPath}
                '';
              }
              // serviceConfigShared;
            };

            ladder-snell-config-watch = {
              description = "Restart ladder-snell only when config content changes";
              after = [ "ladder-snell.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "ladder-snell-restart-on-config" ''
                  set -euo pipefail
                  file='${snellConfigPath}'
                  state='${stateDir}/snell-config.sha256'
                  [[ -r "$file" ]] || exit 0
                  new="$(${pkgs.coreutils}/bin/sha256sum "$file" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
                  old="$(${pkgs.coreutils}/bin/cat "$state" 2>/dev/null || true)"
                  if [[ "$new" != "$old" ]]; then
                    ${pkgs.coreutils}/bin/install -d -m 700 '${stateDir}'
                    printf '%s\n' "$new" > "$state"
                    /run/current-system/sw/bin/systemctl try-restart ladder-snell.service
                  fi
                '';
              };
            };
          };

          paths.ladder-snell-config = {
            wantedBy = [ "multi-user.target" ];
            pathConfig = {
              PathChanged = snellConfigPath;
              Unit = "ladder-snell-config-watch.service";
            };
          };
        };
      })
    ]
  );
}
