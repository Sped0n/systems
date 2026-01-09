{ vars, ... }:
{
  imports = [
    ./docker

    ./ladder.nix
    ./nginx.nix
    ./restic.nix
    ./rclone.nix
    ./telegraf.nix
    ./traefik.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
