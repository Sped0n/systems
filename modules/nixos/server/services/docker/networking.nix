{ pkgs, ... }:
{
  virtualisation.docker.daemon.settings = {
    iptables = false;
    default-address-pools = [
      {
        base = "172.16.0.0/12";
        size = 24;
      }
    ];
  };

  networking.firewall = {
    extraCommands =
      # for docker.host.internal
      ''
        ${pkgs.iptables}/bin/iptables -I nixos-fw 1 -i br+ -j ACCEPT
      ''
      +
      # need to MASQUERADE after we set docker's iptables to false
      ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE
      '';
    extraStopCommands =
      # for docker.host.internal
      ''
        ${pkgs.iptables}/bin/iptables -D nixos-fw -i br+ -j ACCEPT || true
      ''
      +
      # need to MASQUERADE after we set docker's iptables to false
      ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE || true
      '';
    trustedInterfaces = [ "docker0" ];
  };
}
