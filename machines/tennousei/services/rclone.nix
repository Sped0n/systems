{
  config,
  pkgs,
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/qbtrt 0755 ${username} users -"
  ];

  systemd.services.qbtrt-webdav = {
    enable = true;
    description = "WebDAV server for qbittorrent media";
    after = ["network.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = "infinity";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone serve webdav \
          --addr :9999 \
          --htpasswd ${config.age.secrets."rclone-webdav-htpasswd".path} \
          --read-only \
          ${home}/storage/qbtrt
      '';
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
