{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.services.my-ladder;

  stateDir = "/var/lib/ladder";
  keyPath = "${stateDir}/anytls.key";
  certPath = "${stateDir}/anytls.crt";
  ladderConfigPath = config.age.secrets."ladder-config".path;
in
{
  options.services.my-ladder.enable = lib.mkEnableOption "Enable ladder (sing-box) service";

  config = lib.mkIf cfg.enable {
    users.users.ladder = {
      isSystemUser = true;
      group = "ladder";
    };
    users.groups.ladder = { };

    age.secrets."ladder-config" = {
      file = "${secrets}/ages/ladder-config.age";
      owner = "ladder";
      group = "ladder";
      mode = "0400";
    };

    networking.firewall = {
      allowedTCPPorts = [
        443
        23456
      ];
      allowedUDPPorts = [
        443
        23456
      ];
    };

    systemd.services.ladder = {
      description = "ladder sing-box service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "ladder";
        Group = "ladder";

        StateDirectory = "ladder";
        StateDirectoryMode = "0700";

        ExecStartPre = [
          (pkgs.writeShellScript "ladder-init" ''
            set -euo pipefail
            umask 077

            install -d -m 700 "${stateDir}"

            if [ ! -f "${keyPath}" ] || [ ! -f "${certPath}" ]; then
              echo "ladder: generating self-signed certificate..." >&2
              ${pkgs.openssl}/bin/openssl req -x509 \
                -newkey ec:<(${pkgs.openssl}/bin/openssl ecparam -name prime256v1) \
                -keyout "${keyPath}" \
                -out "${certPath}" \
                -days 36500 \
                -nodes \
                -subj "/CN=nus.edu.sg"

              chmod 400 "${keyPath}"
              chmod 444 "${certPath}"
            fi
          '')
        ];
        ExecStart = ''
          ${pkgs.sing-box}/bin/sing-box run -c ${ladderConfigPath}
        '';

        Restart = "on-failure";
        RestartSec = 3;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        ReadWritePaths = [ stateDir ];
        UMask = "0077";
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.tcp_rmem" = "4096 87380 33554432";
      "net.ipv4.tcp_wmem" = "4096 87380 33554432";

      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;

      "net.core.somaxconn" = 65535;
      "net.ipv4.tcp_max_syn_backlog" = 65535;

      "net.ipv4.tcp_keepalive_time" = 600;
      "net.ipv4.tcp_keepalive_intvl" = 10;
      "net.ipv4.tcp_keepalive_probes" = 6;

      "net.mptcp.enabled" = 1;
    };
  };
}
