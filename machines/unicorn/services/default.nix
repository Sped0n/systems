{ vars, ... }:
{
  imports = [
    ./nginx.nix
    ./restic.nix
    ./rclone.nix
    ./docker
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
