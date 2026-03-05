{ vars, ... }:
{
  imports = [
    ./docker

    ./cloudflared.nix
    ./ladder.nix
    ./nginx.nix
    ./restic.nix
    ./telegraf.nix
    ./traefik.nix
    ./vidhub.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
