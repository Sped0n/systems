{
  config,
  pkgs,
  secrets,
  vars,
  ...
}:
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # https://tailscale.com/s/ethtool-config-udp-gro
  system.activationScripts."udp-gro-forwarding".text = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
  '';

  age.secrets."warp-key" = {
    file = "${secrets}/ages/${config.networking.hostName}-warp-key.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."warp0" = {
      autostart = true;
      address = [
        "100.96.0.${vars.${config.networking.hostName}.warpId}/12"
      ];
      mtu = 1380;
      privateKeyFile = config.age.secrets."warp-key".path;
      peers = [
        {
          publicKey = vars.warpPublicKey;
          endpoint = "162.159.193.3:2408";
          allowedIPs = [ "100.96.0.0/12" ];
          persistentKeepalive = 25;
        }
      ];
    };

    firewall = {
      extraCommands = ''
        iptables -t nat -A POSTROUTING -o warp0 -j MASQUERADE
      '';
      extraStopCommands = ''
        iptables -t nat -D POSTROUTING -o warp0 -j MASQUERADE
      '';
      trustedInterfaces = [ "warp0" ];
    };
  };
}
