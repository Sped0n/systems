{ pkgs-unstable, ... }:
{
  networking.firewall = {
    extraCommands = ''
      iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
    '';
    extraStopCommands = ''
      iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE
    '';
    trustedInterfaces = [ "tailscale0" ];
  };

  services.tailscale = {
    enable = true;
    # FIXME: see https://github.com/NixOS/nixpkgs/issues/438765
    package = pkgs-unstable.tailscale.overrideAttrs { doCheck = false; };
    interfaceName = "tailscale0";
    openFirewall = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
