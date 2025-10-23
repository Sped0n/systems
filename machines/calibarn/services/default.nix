{ home, username, ... }:
{
  imports = [
    ./docker.nix
    ./restic.nix
    ./runner.nix
  ];

  systemd.tmpfiles.rules = [
    "d ${home}/others 0755 ${username} users -"
  ];
}
