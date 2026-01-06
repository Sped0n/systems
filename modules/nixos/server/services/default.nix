{
  imports = [
    ./telegraf

    ./builder.nix
    ./cfgpull.nix
    ./docker.nix
    ./ladder.nix
    ./msmtp.nix
    ./restic.nix
    ./runner.nix
    ./sshd.nix
    ./traefik.nix
  ];
}
