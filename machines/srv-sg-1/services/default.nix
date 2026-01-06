{ vars, ... }:
{
  imports = [
    ./docker.nix
    ./ladder.nix
    ./restic.nix
    ./runner.nix
    ./telegraf.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
