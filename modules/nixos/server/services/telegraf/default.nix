{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  cfg = config.services.my-telegraf;
in
{
  options.services.my-telegraf = {
    enable = lib.mkEnableOption "the my-telegraf bundle";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-unstable.telegraf;
      description = "Telegraf package used by services.my-telegraf.";
    };
  };

  imports = [
    ./inputs.nix
    ./osinfo.nix
    ./outputs.nix
    ./syslog.nix
  ];

  config = lib.mkIf cfg.enable {
    users.users.telegraf.extraGroups = [
      "docker"
      "nixos-info-updater"
    ];

    services.telegraf = {
      enable = true;
      package = cfg.package;
      extraConfig.agent = {
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
    };

    systemd.services.telegraf = {
      requires = [ "nixos-info-update.service" ];
      after = [ "nixos-info-update.service" ];
      serviceConfig.AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    };
  };
}
