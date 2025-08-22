{ pkgs-unstable, ... }:
{
  networking.firewall = {
    extraCommands = ''
      iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
    '';
    extraStopCommands = ''
      iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE || true
    '';
    trustedInterfaces = [ "tailscale0" ];
  };

  services.tailscale = {
    enable = true;
    package = pkgs-unstable.tailscale;
    interfaceName = "tailscale0";
    openFirewall = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
