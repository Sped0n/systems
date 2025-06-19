{
  pkgs,
  pkgs-unstable,
  config,
  ...
}: {
  services.telegraf = {
    enable = true;
    package = pkgs-unstable.telegraf;
    extraConfig = {
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
        system = {};
        kernel.collect = ["psi"];
        exec = [
          {
            name_override = "kversion";
            commands = ["${pkgs.coreutils}/bin/uname -r"];
            interval = "10m";
            timeout = "5s";
            data_format = "value";
            data_type = "string";
            tags = {
              metric_type = "misc";
              log_source = "telegraf";
            };
          }
        ];
        cpu.fieldexclude = ["time_*"];
        mem = {};
        swap = {};
        disk = {
          mount_points = ["/"];
        };
        diskio = {
          devices = ["sda" "vda"];
        };
        net = {
          interfaces = ["eth0" "tailscale0"];
          fieldexclude = ["speed"];
        };
        netstat = {};
        docker = {
          timeout = "10s";
          source_tag = true;
          docker_label_exclude = ["traefik.*"];
        };
      };

      outputs = {
        influxdb = {
          urls = ["http://tsuki:8428"];
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
            "docker*"
          ];
        };
        loki = [
          {
            domain = "http://tsuki:9428";
            endpoint = "/insert/loki/api/v1/push";
            gzip_request = true;
            sanitize_label_names = true;
            namepass = ["kversion"];
          }
        ];
      };
    };
  };

  users.users.telegraf.extraGroups = ["docker"];
  systemd.services.telegraf.after = ["tailscaled.service"];
}
