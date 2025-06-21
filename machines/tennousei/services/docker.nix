{
  pkgs,
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/qbtrt 0755 ${username} users -"
    "d ${home}/storage/syncthing 0755 ${username} users -"
  ];

  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  };

  services.logrotate = {
    enable = true;
    settings = {
      "${home}/infra/data/traefik/access.log" = {
        "create 755 ${username} users" = true;
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
