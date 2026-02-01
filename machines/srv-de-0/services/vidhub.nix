{
  config,
  pkgs,
  secrets,
  vars,
  ...
}:
{
  users = {
    users.vidhub = {
      isSystemUser = true;
      group = "vidhub";
    };
    groups.vidhub = { };
  };

  age.secrets."srv-de-0-vidhub-htpasswd" = {
    file = "${secrets}/ages/srv-de-0-vidhub-htpasswd.age";
    owner = "vidhub";
    mode = "0400";
  };

  systemd.services.vidhub = {
    description = "WebDAV server for qBittorrent media";
    after = [ "network.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.RCLONE_CONFIG = "/tmp/rclone.conf";
    serviceConfig = {
      User = "vidhub";
      Group = "vidhub";
      Restart = "on-failure";
      RestartSec = "5s";

      ExecStart = ''
        ${pkgs.rclone}/bin/rclone serve webdav \
          --addr :9999 \
          --htpasswd ${config.age.secrets."srv-de-0-vidhub-htpasswd".path} \
          --read-only \
          --dir-cache-time 1m \
          --buffer-size 32M \
          --vfs-read-ahead 64M \
          --log-level NOTICE \
          --stats 0 \
          ${vars.home}/storage/qb
      '';

      LimitNOFILE = 65536;

      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      PrivateTmp = true;
      BindReadOnlyPaths = [ "${vars.home}/storage/qb" ];

      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;

      KeyringMode = "private";
    };
  };

  services.my-traefik = {
    dynamicConfigOptions = {
      http = {
        routers.vidhub = {
          rule = "Host(`vidhub.sped0n.com`)";
          entryPoints = [ "https" ];
          tls = true;
          service = "vidhub";
          middlewares = [ "cftunnel@file" ];
        };
        services.vidhub.loadBalancer.servers = [
          { url = "http://localhost:9999"; }
        ];
      };
    };
  };
}
