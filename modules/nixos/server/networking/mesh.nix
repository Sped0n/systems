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

  age.secrets."mesh-key" = {
    file = "${secrets}/ages/${config.networking.hostName}-mesh-key.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."mesh0" = {
      autostart = true;
      address = [
        "10.42.0.${vars.${config.networking.hostName}.meshId}/24"
      ];
      listenPort = 41616;
      mtu = 1380;
      privateKeyFile = config.age.secrets."mesh-key".path;
      postUp = "${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o mesh0 -j MASQUERADE";
      postDown = "${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o mesh0 -j MASQUERADE";
      peers =
        let
          others = builtins.filter (n: n != config.networking.hostName) [
            "srv-de-0"
            "srv-nl-0"
            "srv-sg-0"
            "srv-sg-1"
            "srv-us-0"
          ];
        in
        map (name: {
          publicKey = vars.${name}.meshPublicKey;
          endpoint = "${vars.${name}.ipv4}:41616";
          allowedIPs = [ "10.42.0.${vars.${name}.meshId}/32" ];
          persistentKeepalive = 25;
        }) others
        ++ [
          # wks-0
          {
            publicKey = "66uBHZQjwyAbtnvpXQh7bU/Xc984SFWocsFwOAgykC0=";
            allowedIPs = [ "10.42.0.101/32" ];
          }
          # mbn-0
          {
            publicKey = "v8itgxpc8IppHVSZJY823/nsA/WX+F7abAOLbyZlFmI=";
            allowedIPs = [ "10.42.0.102/32" ];
          }
          # tab-0
          {
            publicKey = "M4TLPy1EH42+0lSn6b4eqt8enKyI7QwInf52SHaMBCA=";
            allowedIPs = [ "10.42.0.103/32" ];
          }
        ];
    };

    firewall = {
      allowedUDPPorts = [ 41616 ];
      trustedInterfaces = [ "mesh0" ];
      checkReversePath = false;
    };
  };
}
