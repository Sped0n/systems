{
  config,
  pkgs,
  lib,
  secrets,
  vars,
  ...
}:
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # https://tailscale.com/s/ethtool-config-udp-gro
  system.activationScripts."udp-gro-forwarding".text = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
  '';

  age.secrets."warp-key" = {
    file = "${secrets}/ages/${config.networking.hostName}-warp-key.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."warp0" = {
      autostart = true;
      address = [
        "100.96.0.${vars.${config.networking.hostName}.warpId}/12"
      ];
      mtu = 1380;
      privateKeyFile = config.age.secrets."warp-key".path;
      peers = [
        {
          publicKey = vars.warpPublicKey;
          endpoint = "162.159.193.3:2408";
          allowedIPs = [ "100.96.0.0/12" ];
          persistentKeepalive = 25;
        }
      ];
    };

    firewall = {
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o warp0 -j MASQUERADE
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o warp0 -j MASQUERADE
      '';
      trustedInterfaces = [ "warp0" ];
    };
  };

  systemd = {
    services.ping-warp-peers = {
      description = "Ping Warp peers to keep the connection alive";
      after = [ "wg-quick-warp0.service" ];
      requires = [ "wg-quick-warp0.service" ];
      partOf = [ "wg-quick-warp0.service" ];
      wantedBy = [ "wg-quick-warp0.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "ping-warp-peers" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail; for ip in ${
            lib.concatStringsSep " " (
              map (h: "100.96.0.${toString vars.${h}.warpId}") (
                builtins.filter (h: h != config.networking.hostName) [
                  "srv-de-0"
                  "srv-nl-0"
                  "srv-sg-0"
                  "srv-sg-1"
                  "srv-us-0"
                ]
              )
            )
          }; do ${pkgs.iputils}/bin/ping -c 3 -W 2 "$ip" || true; done
        '';
      };
    };

    timers.ping-warp-peers = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
        Unit = "ping-warp-peers.service";
      };
    };
  };
}
