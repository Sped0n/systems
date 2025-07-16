{
  config,
  pkgs,
  home,
  username,
  ...
}: {
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
      serviceConfig = {
        User = username;
        Group = "users";
        Restart = "on-failure";
        RestartSec = "5s";

        ExecStart = ''
          ${pkgs.rclone}/bin/rclone serve webdav \
            --addr :9999 \
            --htpasswd ${config.age.secrets."rclone-webdav-htpasswd".path} \
            --read-only \
            ${home}/storage/qbtrt
        '';

        KeyringMode = "private";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        RemoveIPC = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
