{
  config,
  secrets,
  ...
}:
{
  age.secrets."wg0-conf" = {
    file = "${secrets}/ages/exia-wg0-conf.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."wg0" = {
      configFile = config.age.secrets."wg0-conf".path;
      autostart = true;
    };

    firewall = {
      allowedTCPPorts = [ 55555 ];
      allowedUDPPorts = [
        55555
        51820
      ];
      checkReversePath = false;
    };
  };

  # https://rakhesh.com/linux-bsd/tailscale-wireguard-co-existing-or-i-love-policy-based-routing
  systemd.services.tailscaled.after = [ "wg-quick-wg0.service" ];

  services.telegraf = {
    extraConfig = {
      inputs = {
        wireguard.devices = [ "wg0" ];
      };

      outputs = {
        influxdb.namepass = [ "wireguard*" ];
      };
    };
  };

  systemd.services.telegraf.serviceConfig.AmbientCapabilities = [ "CAP_NET_ADMIN" ];
}
