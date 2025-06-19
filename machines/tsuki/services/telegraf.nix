{...}: {
  services.telegraf = {
    extraConfig = {
      inputs = {
        wireguard.devices = ["wg0"];
      };
    };
  };

  systemd.services.telegraf.serviceConfig.AmbientCapabilities = ["CAP_NET_ADMIN"];
}
