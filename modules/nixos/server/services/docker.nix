{...}: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      iptables = false;
      max-concurrent-downloads = 2;
    };
  };

  networking.firewall = {
    extraCommands =
      # For docker.host.internal
      ''
        iptables -I INPUT 1 -s 172.16.0.0/12 -p tcp -d 172.17.0.1 -j ACCEPT
        iptables -I INPUT 2 -s 172.16.0.0/12 -p udp -d 172.17.0.1 -j ACCEPT
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      '';
    extraStopCommands =
      # For docker.host.internal
      ''
        iptables -D INPUT -s 172.16.0.0/12 -p tcp -d 172.17.0.1 -j ACCEPT || true
        iptables -D INPUT -s 172.16.0.0/12 -p udp -d 172.17.0.1 -j ACCEPT || true
      ''
      +
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE || true
        iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE || true
      '';
    trustedInterfaces = ["docker0"];
    checkReversePath = false;
  };
}
