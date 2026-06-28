{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  my-docker = config.services.my-docker;
  dockerAddressPools = config.virtualisation.docker.daemon.settings."default-address-pools" or [ ];

  dockerSubnets = map (pool: pool.base) dockerAddressPools;
in
{
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

  # https://tailscale.com/s/ethtool-config-udp-gro
  system.activationScripts."tailscale-udp-gro-forwarding".text = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
  '';

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
  }
  // lib.optionalAttrs my-docker.enable {
    extraCommands = lib.concatMapStringsSep "\n" (subnet: ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${subnet} -o tailscale0 -j MASQUERADE
    '') dockerSubnets;
    extraStopCommands = lib.concatMapStringsSep "\n" (subnet: ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${subnet} -o tailscale0 -j MASQUERADE || true
    '') dockerSubnets;
  };
}
