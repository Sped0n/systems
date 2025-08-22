{
  home,
  username,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${home}/others 0755 ${username} users -"
    "d ${home}/sharing 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/qbtrt 0755 ${username} users -"
    "d ${home}/storage/syncthing 0755 ${username} users -"
  ];

  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [
      22000
      21027
    ];
  };

  services = {
    logrotate = {
      enable = true;
      settings = {
        "/var/log/traefik/access.log" = {
          copytruncate = true;
          frequency = "hourly";
          size = "100K";
          rotate = 0;
          missingok = true;
          notifempty = true;
        };

        "${home}/infra/data/vaultwarden/vaultwarden.log" = {
          copytruncate = true;
          frequency = "daily";
          size = "10M";
          rotate = 3;
          missingok = true;
          notifempty = true;
        };
      };
    };

    docuum = {
      enable = true;
      threshold = "25GB";
    };
  };

  systemd.services.docuum.environment.LOG_LEVEL = "info";
}
