{
  config,
  home,
  pkgs,
  secrets,
  username,
  ...
}: {
  users.users.rclone-webdav = {
    isSystemUser = true;
    group = "rclone-webdav";
  };
  users.groups.rclone-webdav = {};

  age.secrets."rclone-webdav-htpasswd" = {
    file = "${secrets}/ages/tennousei-rclone-webdav-htpasswd.age";
    owner = "rclone-webdav";
    mode = "0400";
  };

  systemd = {
    tmpfiles.rules = [
      "d ${home}/storage 0755 ${username} users -"
      "d ${home}/storage/qbtrt 0755 ${username} users -"
    ];

    services.qbtrt-webdav = {
      description = "WebDAV server for qbittorrent media";
      after = ["network.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      environment.RCLONE_CONFIG = "/tmp/rclone.conf";
      serviceConfig = {
        User = "rclone-webdav";
        Group = "rclone-webdav";
        Restart = "on-failure";
        RestartSec = "5s";

        ExecStart = ''
          ${pkgs.rclone}/bin/rclone serve webdav \
            --addr :9999 \
            --htpasswd ${config.age.secrets."rclone-webdav-htpasswd".path} \
            --read-only \
            --dir-cache-time 10s \
            ${home}/storage/qbtrt
        '';

        ProtectSystem = "strict";
        ProtectHome = "tmpfs";
        PrivateTmp = true;
        BindReadOnlyPaths = ["${home}/storage/qbtrt"];

        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictSUIDSGID = true;

        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;

        KeyringMode = "private";
        RemoveIPC = true;
        RestrictRealtime = true;
      };
    };
  };
}
