{
  config,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  meshPort = 41641;
in
{
  boot = {
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    kernelModules = [ "wireguard" ];
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
        "100.96.0.${vars.${config.networking.hostName}.meshId}/16"
      ];
      listenPort = meshPort;
      mtu = 1380;
      privateKeyFile = config.age.secrets."mesh-key".path;
      peers =
        let
          others = builtins.filter (n: n != config.networking.hostName) vars.serverHostnames;
        in
        map (name: {
          publicKey = vars.${name}.meshPublicKey;
          endpoint = "${vars.${name}.ipv4}:${toString meshPort}";
          allowedIPs = [ "100.96.0.${vars.${name}.meshId}/32" ];
          persistentKeepalive = 25;
        }) others
        ++ [
          # wks-0
          {
            publicKey = "Jd40BFeb2wInYaQByBlX35uFz72P1dzAMvdjwBBBM0s=";
            allowedIPs = [ "100.96.1.1/32" ];
          }
          # phn-0
          {
            publicKey = "CN30BPAOfCgUQlyhZ3TrpxALO/j0rXwaT4a1Ef6UiQE=";
            allowedIPs = [ "100.96.1.2/32" ];
          }
          # tab-0
          {
            publicKey = "o4T+i8q1DSFU3JSkiafQWWSOSpMlBQt1c4bwL2jz9ig=";
            allowedIPs = [ "100.96.1.3/32" ];
          }
        ];
    };

    firewall = {
      allowedUDPPorts = [ meshPort ];
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -o mesh0 -j MASQUERADE
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 172.16.0.0/12 -o mesh0 -j MASQUERADE || true
      '';
      trustedInterfaces = [ "mesh0" ];
    };
  };
}
