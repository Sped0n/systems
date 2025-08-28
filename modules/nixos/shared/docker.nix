{ ... }:
{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      iptables = false;
      max-concurrent-downloads = 2;
      log-driver = "journald";
      log-opts = {
        tag = "docker#{{.Name}}({{.ID}})";
      };
      default-address-pools = [
        {
          base = "172.16.0.0/12";
          size = 24;
        }
      ];
    };
  };

  networking.firewall = {
    extraCommands =
      # For docker.host.internal
      ''
        iptables -I nixos-fw 1 -i br+ -j ACCEPT
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      '';
    extraStopCommands =
      # For docker.host.internal
      ''
        iptables -D nixos-fw -i br+ -j ACCEPT
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
      '';
    trustedInterfaces = [ "docker0" ];
  };
}
