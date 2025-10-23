{ home, username, ... }:
{
  imports = [
    ./nginx.nix
    ./restic.nix
    ./rclone.nix
    ./docker
  ];

  systemd.tmpfiles.rules = [
    "d ${home}/others 0755 ${username} users -"
  ];
}
