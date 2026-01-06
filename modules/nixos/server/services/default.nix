{
  imports = [
    ./telegraf

    ./builder.nix
    ./cfgpull.nix
    ./docker.nix
    ./msmtp.nix
    ./restic.nix
    ./runner.nix
    ./ss.nix
    ./sshd.nix
    ./traefik.nix
  ];
}
