{
  config,
  lib,
  secrets,
  ...
}:
let
  my-ladder = config.services.my-ladder;
in
{
  imports = [
    ./exit.nix
    ./relay.nix
  ];

  config = lib.mkIf (my-ladder.relay.enable || my-ladder.exit.enable) {
    users = {
      users.ladder = {
        isSystemUser = true;
        group = "ladder";
      };
      groups.ladder = { };
    };

    age.secrets."ladder-password" = {
      file = "${secrets}/ages/ladder-password.age";
      owner = "ladder";
      group = "ladder";
      mode = "0400";
    };

    boot.kernel.sysctl = {
      "net.ipv4.tcp_keepalive_time" = 300;
      "net.ipv4.tcp_keepalive_intvl" = 30;
      "net.ipv4.tcp_keepalive_probes" = 3;
      "net.ipv4.tcp_tw_reuse" = 1;
    };

    systemd.services.ladder = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "ladder";
        Group = "ladder";
        StateDirectory = "ladder";
        StateDirectoryMode = "0750";
        UMask = "0077";
        LimitNOFILE = 262144;
        TasksMax = "infinity";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 5;
        KillMode = "mixed";

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = false;
        LockPersonality = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        PrivateDevices = false;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        DeviceAllow = [ "/dev/net/tun rw" ];
      };
    };

    services.fail2ban.jails.ladder = {
      filter.Definition.failregex =
        "^.*process connection from <HOST>:\\d+: "
        + "(unknown user password"
        + "|TLS handshake: tls:"
        + "|TLS handshake: remote error:)";
      settings = {
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=ladder.service";
        findtime = "1d";
      };
    };
  };
}
