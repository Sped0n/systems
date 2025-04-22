{
  pkgs,
  home,
  username,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  networking.firewall = {
    allowedUDPPorts = [21027 22000];
    allowedTCPPorts = [22000];
    extraCommands = ''
      iptables -I INPUT 1 -s 172.16.0.0/12 -p tcp -d 172.17.0.1 -j ACCEPT
      iptables -I INPUT 2 -s 172.16.0.0/12 -p udp -d 172.17.0.1 -j ACCEPT
    '';
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
