{ config, lib, ... }:
let
  cfg = config.services.my-telegraf;
in
{
  config = lib.mkIf cfg.enable {
    services.telegraf.extraConfig.inputs =
      let
        tags = {
          metric_type = "logs";
          log_source = "telegraf";
        };
      in
      {
        system = { };
        kernel.collect = [ "psi" ];
        cpu.fieldexclude = [ "time_*" ];
        mem = { };
        swap = { };
        disk.mount_points = [ "/" ];
        diskio.devices = [
          "sda"
          "vda"
        ];
        net = {
          interfaces = [
            "eth0"
            "tailscale0"
          ];
          fieldexclude = [ "speed" ];
          ignore_protocol_stats = true;
        };
        netstat = { };
        docker = {
          timeout = "10s";
          source_tag = true;
          docker_label_exclude = [
            "traefik.*"
            "com.*"
            "org.*"
            "io.*"
            "summary"
            "description"
          ];
        };
        processes = { };
        syslog = {
          inherit tags;
          server = "tcp://127.0.0.1:6514";
          tagexclude = [
            "source"
            "hostname"
          ];
          fieldexclude = [
            "version"
            "severity_code"
            "facility_code"
            "timestamp"
          ];
        };
        tail = [
          {
            inherit tags;
            files = [ "/var/log/nixos-info/nixos-info.log" ];
            name_override = "info_system";
            initial_read_offset = "beginning";
            watch_method = "inotify";
            data_format = "logfmt";
          }
        ];
      };
  };
}
