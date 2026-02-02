{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  my-ladder = config.services.my-ladder;

  stateDir = "/var/lib/ladder";
  keyPath = "${stateDir}/disguise.key";
  certPath = "${stateDir}/disguise.crt";
  ladderConfigPath = config.age.secrets."ladder-config".path;
in
{
  options.services.my-ladder.enable = lib.mkEnableOption "Enable ladder (sing-box) service";

  config = lib.mkIf my-ladder.enable {
    users = {
      users.ladder = {
        isSystemUser = true;
        group = "ladder";
      };
      groups.ladder = { };
    };

    age.secrets."ladder-config" = {
      file = "${secrets}/ages/ladder-config.age";
      owner = "ladder";
      group = "ladder";
      mode = "0400";
    };

    networking.firewall.allowedTCPPorts = [ 443 ];

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
        UMask = "0077";

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
          ${pkgs.sing-box}/bin/sing-box run -c ${ladderConfigPath}
        '';

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
    };

    boot.kernel.sysctl = {
      "net.ipv4.tcp_keepalive_time" = 300;
      "net.ipv4.tcp_keepalive_intvl" = 30;
      "net.ipv4.tcp_keepalive_probes" = 3;
      "net.ipv4.tcp_tw_reuse" = 1;
    };

    services.fail2ban.jails.singbox = {
      filter.Definition.failregex =
        "^.*process connection from <HOST>:\\d+: "
        + "(unknown user password"
        + "|TLS handshake: tls:"
        + "|TLS handshake: remote error:)";
      settings = {
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=ladder.service";
        findtime = "6h";
      };
    };
  };
}
