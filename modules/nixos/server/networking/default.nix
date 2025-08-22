{ ... }:
{
  imports = [
    ../../shared/networking.nix

    ./sshd.nix
    ./tailscale.nix
  ];
}
