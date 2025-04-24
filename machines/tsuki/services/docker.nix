{
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"

    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/syncthing 0755 ${username} users -"
  ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      iptables = false;
      max-concurrent-downloads = 2;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
    extraCommands =
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      '';
    extraStopCommands =
      # Need to MASQUERADE after we set docker's iptables to false
      ''
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE || true
        iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE || true
      '';
    trustedInterfaces = ["docker0"];
    checkReversePath = false;
  };
}
