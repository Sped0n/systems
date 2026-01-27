{
  config,
  functions,
  lib,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  my-telegraf = config.services.my-telegraf;

  toml = pkgs.formats.toml { };
in
{
  imports = [
    ./osinfo.nix
    ./syslog.nix
  ];

  options.services.my-telegraf = {
    enable = lib.mkEnableOption "Whether to enable the custom Telegraf module.";

    extraConfig = lib.mkOption {
      description = ''
        Extra configuration options for custom Telegraf module.
      '';
      type = toml.type;
      default = { };
    };

    syslogExtraFilters = lib.mkOption {
      type = with lib.types; attrsOf lines;
      default = { };
      description = ''
        Extra syslog-ng filters to be appended to the Telegraf syslog-ng log path.

        Attribute names become filter names `f_<name>`.
        Values must be valid syslog-ng filter bodies (the content inside `{ ... }`),
        typically ending statements with `;`.
      '';
      example = {
        ignore_restic = ''
          not (
            program("restic") and
            level(info)
          );
        '';
      };
    };
  };

  config = lib.mkIf my-telegraf.enable {
    services.telegraf = {
      enable = true;
      package = pkgs-unstable.telegraf;
      extraConfig = functions.mergeToml {
        agent = {
          interval = "10s";
          round_interval = true;
          metric_batch_size = 1000;
          metric_buffer_limit = 100000;
          collection_jitter = "0s";
          flush_interval = "10s";
          flush_jitter = "0s";
          precision = "";
          debug = false;
          quiet = false;
          logfile = "/dev/null";
          hostname = config.networking.hostName;
          omit_hostname = false;
        };

        inputs = {
          system = { };
          kernel.collect = [ "psi" ];
          cpu.fieldexclude = [ "time_*" ];
          mem = { };
          swap = { };
          disk.mount_points = [ "/" ];
          diskio.devices = [
            "sda"
            "vda"
            "nvme0n1"
          ];
          net = {
            interfaces = [ "eth0" ];
            fieldexclude = [ "speed" ];
          };
          netstat = { };
          processes = { };
        };

        outputs.influxdb = [
          {
            urls = [ "http://100.96.0.${vars."srv-de-0".meshId}:8428" ];
            database = "victoriametrics";
            skip_database_creation = true;
            exclude_retention_policy_tag = true;
            content_encoding = "gzip";
            namepass = [
              "system*"
              "kernel*"
              "cpu*"
              "mem*"
              "swap*"
              "disk*"
              "diskio*"
              "net*"
              "netstat*"
              "processes*"
            ];
          }
        ];
      } my-telegraf.extraConfig;
    };

    systemd.services.telegraf.serviceConfig = {
      LimitNOFILE = 8192;
    };
  };
}
