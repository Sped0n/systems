{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
    ./docker.nix
    ./ladder.nix
    ./restic.nix
    ./runner.nix
    ./telegraf.nix
    ./traefik.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
