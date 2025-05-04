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

  boot.kernel.sysctl = {
    "vm.overcommit_memory" = 1;
  };

  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
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
