{
  pkgs,
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"

    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/qbtrt 0755 ${username} users -"
    "d ${home}/storage/syncthing 0755 ${username} users -"
  ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      iptables = false;
      max-concurrent-downloads = 2;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
    extraCommands =
      # For docker.host.internal
      ''
        iptables -I INPUT 1 -s 172.16.0.0/12 -p tcp -d 172.17.0.1 -j ACCEPT
        iptables -I INPUT 2 -s 172.16.0.0/12 -p udp -d 172.17.0.1 -j ACCEPT
        iptables -I INPUT 3 -s 192.168.0.0/16 -p tcp -d 172.17.0.1 -j ACCEPT
        iptables -I INPUT 4 -s 192.168.0.0/16 -p udp -d 172.17.0.1 -j ACCEPT
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      '';
    extraStopCommands =
      # For docker.host.internal
      ''
        iptables -D INPUT -s 172.16.0.0/12 -p tcp -d 172.17.0.1 -j ACCEPT || true
        iptables -D INPUT -s 172.16.0.0/12 -p udp -d 172.17.0.1 -j ACCEPT || true
        iptables -D INPUT -s 192.168.0.0/16 -p tcp -d 172.17.0.1 -j ACCEPT || true
        iptables -D INPUT -s 192.168.0.0/16 -p udp -d 172.17.0.1 -j ACCEPT || true
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE || true
        iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE || true
      '';
    trustedInterfaces = ["docker0"];
    checkReversePath = false;
  };

  services.logrotate = {
    enable = true;
    settings = {
      "${home}/infra/data/traefik/logs/access.log" = {
        "create 0644 root root" = true;
        frequency = "daily";
        size = "10M";
        rotate = 3;
        missingok = true;
        notifempty = true;
        postrotate = ''
          echo "Attempting to signal Traefik container..." >&2
          ${pkgs.docker}/bin/docker exec traefik kill -USR1 1 || echo "Failed to signal PID 1 in Docker container 'traefik'" >&2
        '';
      };

      "${home}/infra/data/vaultwarden/vaultwarden.log" = {
        "create 0755 ${username} users" = true;
        frequency = "daily";
        size = "10M";
        rotate = 3;
        missingok = true;
        notifempty = true;
      };
    };
  };
}
