{ ... }:
{
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
