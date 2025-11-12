{ ... }:
{
  imports = [
    ./cloudflared.nix
    ./sshd.nix
    ./tailscale.nix
  ];
}
