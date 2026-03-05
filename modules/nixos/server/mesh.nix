{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  hostname = config.networking.hostName;
  my-telegraf = config.services.my-telegraf;

  meshPort = 41641;
  hub = "srv-sg-1";
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
    file = "${secrets}/ages/${hostname}-mesh-key.age";
    owner = "root";
    mode = "0400";
  };

  networking = {
    wg-quick.interfaces."mesh0" = {
      autostart = true;
      address = [
        "100.96.0.${vars.${hostname}.meshId}/16"
      ];
      listenPort = meshPort;
      mtu = 1380;
      privateKeyFile = config.age.secrets."mesh-key".path;
      peers =
        let
          others = builtins.filter (n: (n != hostname && n != hub)) vars.serverHostnames;
        in
        map (name: {
          publicKey = vars.${name}.meshPublicKey;
          endpoint = "${vars.${name}.ipv4}:${toString meshPort}";
          allowedIPs = [ "100.96.0.${vars.${name}.meshId}/32" ];
          persistentKeepalive = 25;
        }) others
        ++ [
          # hub
          {
            publicKey = vars.${hub}.meshPublicKey;
            endpoint = "${vars.${hub}.ipv4}:${toString meshPort}";
            allowedIPs = [
              "100.96.0.${vars.${hub}.meshId}/32"
              "100.96.1.0/24"
            ];
            persistentKeepalive = 25;
          }
        ]
        ++ lib.optionals (hostname == hub) [
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

    extraHosts = builtins.concatStringsSep "\n" (
      map (name: "100.96.0.${toString vars.${name}.meshId} ${name}") vars.serverHostnames
    );

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

  services.my-telegraf.extraConfig = lib.mkIf my-telegraf.enable {
    inputs = {
      wireguard = {
        devices = [ "mesh0" ];
        fieldexclude = [
          "listen_port"
          "firewall_mark"
          "peers"
          "persistent_keepalive_interval_ns"
          "protocol_version"
          "allowed*"
        ];
      };
      ping = [
        {
          name_override = "mesh_ping";
          fieldexclude = [
            "packets_*"
            "ttl"
            "minimum_response_ms"
            "maximum_response_ms"
            "standard_deviation_ms"
            "percentile*"
          ];
          urls = vars.serverHostnames;
          method = "native";
          ping_interval = 30.0;
          count = 5;
        }
      ];
    };

    outputs.influxdb = [
      {
        urls = [ "http://100.96.0.${vars."srv-de-0".meshId}:8428" ];
        database = "victoriametrics";
        skip_database_creation = true;
        exclude_retention_policy_tag = true;
        content_encoding = "gzip";
        namepass = [
          "wireguard*"
          "mesh_ping*"
        ];
      }
    ];
  };
}
