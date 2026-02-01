{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  my-telegraf = config.services.my-telegraf;
in
{
  age.secrets."torrent-key" = {
    file = "${secrets}/ages/srv-nl-0-torrent-key.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."torrent0" = {
      autostart = true;
      address = [ "10.8.0.1/32" ];
      listenPort = 51820;
      mtu = 1380;
      privateKeyFile = config.age.secrets."torrent-key".path;
      postUp = "${pkgs.iptables}/bin/iptables -A FORWARD -i torrent0 -j ACCEPT; ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE";
      postDown = "${pkgs.iptables}/bin/iptables -D FORWARD -i torrent0 -j ACCEPT; ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE";
      peers = [
        {
          publicKey = "GHPtArq9Vns3/KgZc+Kd3xg2kmvafcCX1HXNK6rMpmg=";
          allowedIPs = [ "10.8.0.2/32" ];
        }
      ];
    };

    firewall = {
      allowedTCPPorts = [ 55555 ];
      allowedUDPPorts = [
        55555
        51820
      ];
    };
  };

  services.my-telegraf.extraConfig = lib.mkIf my-telegraf.enable {
    inputs.wireguard.devices = [ "torrent0" ];
  };
}
