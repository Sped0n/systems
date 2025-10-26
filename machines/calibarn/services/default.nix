{ vars, ... }:
{
  imports = [
    ./docker.nix
    ./restic.nix
    ./runner.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
  ];
}
