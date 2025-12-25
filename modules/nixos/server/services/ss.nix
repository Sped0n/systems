{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
let
  cfg = config.services.my-ss;
  ssConfigPath = config.age.secrets."ss-config".path;
in
{
  options.services.my-ss.enable = lib.mkEnableOption "Enable shadowsocks-rust server (my-ss)";

  config = lib.mkIf cfg.enable {
    users.users.my-ss = {
      isSystemUser = true;
      group = "my-ss";
    };
    users.groups.my-ss = { };

    age.secrets."ss-config" = {
      file = "${secrets}/ages/ss-config.age";
      owner = "my-ss";
      group = "my-ss";
      mode = "0400";
    };

    systemd.services.my-ss = {
      description = "Shadowsocks-rust Default Server Service (my-ss)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "my-ss";
        Group = "my-ss";
        LimitNOFILE = 32768;
        ExecStart = ''
          ${pkgs-unstable.shadowsocks-rust}/bin/ssserver -c ${ssConfigPath}
        '';
        ExecStop = "${pkgs.coreutils}/bin/killall ssserver";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ vars.ssPort ];
      allowedUDPPorts = [ vars.ssPort ];
    };

    boot.kernel.sysctl = {
      "net.ipv4.tcp_rmem" = "4096 87380 33554432";
      "net.ipv4.tcp_wmem" = "4096 87380 33554432";

      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;

      "net.core.somaxconn" = 65535;
      "net.ipv4.tcp_max_syn_backlog" = 65535;

      "net.ipv4.tcp_fastopen" = 3;

      "net.ipv4.tcp_keepalive_time" = 600;
      "net.ipv4.tcp_keepalive_intvl" = 10;
      "net.ipv4.tcp_keepalive_probes" = 6;

      "net.core.rmem_default" = 1048576;
    };
  };
}
