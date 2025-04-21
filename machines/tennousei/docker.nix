{pkgs, ...}: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      "iptables" = false;
    };
  };

  networking.firewall = {
    extraCommands = ''
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
    '';
    trustedInterfaces = ["docker0"];
    checkReversePath = false;
  };

  services.logrotate = {
    enable = true;
    settings = {
      traefik = {
        path = "/home/spedon/infra/data/traefik/logs/access.log";
        frequency = "daily";
        size = "10M";
        rotate = 3;
        missingok = true;
        notifempty = true;
        create = true;
        postrotate = ''
          echo "Attempting to signal Traefik container..." >&2
          ${pkgs.docker}/bin/docker exec traefik kill -USR1 1 || echo "Failed to signal PID 1 in Docker container 'traefik'" >&2
        '';
      };

      vaultwarden = {
        path = "/home/spedon/infra/data/vaultwarden/vaultwarden.log";
        frequency = "daily";
        size = "10M";
        rotate = 3;
        missingok = true;
        notifempty = true;
        copytruncate = true;
      };
    };
  };
}
