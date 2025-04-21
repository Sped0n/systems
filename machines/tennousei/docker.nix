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
        path = "/home/spedon/infra/data/traefik/logs/*.log";

        frequency = "daily"; # Check daily for rotation needs
        size = "10M"; # Rotate if log file exceeds 10 Megabytes
        rotate = 7; # Keep the last 7 rotated log files

        compress = true; # Compress rotated logs (usually with gzip)
        delaycompress = true; # Don't compress the log until the *next* rotation cycle
        # (useful if you need to access the most recent rotated log quickly)
        missingok = true; # Don't issue an error if the log file doesn't exist
        notifempty = true; # Don't rotate the log file if it's empty

        create = true; # Creates with default perms (often root:root 0644/0600 depending on logrotate version/defaults)

        postrotate = ''
          echo "Attempting to signal Traefik container..." >&2
          ${pkgs.docker}/bin/docker exec traefik kill -USR1 1 || echo "Failed to signal PID 1 in Docker container 'traefik'" >&2
        '';

        sharedscripts = true;
      };
    };
  };
}
