{config, ...}: {
  services.telegraf = {
    enable = true;
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
        cpu.fielddrop = ["time_*"];
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
          fielddrop = ["speed"];
        };
        netstat = {};
        docker = {};
      };

      outputs = {
        influxdb = {
          urls = ["http://100.122.137.55:8428"];
          database = "victoriametrics";
          skip_database_creation = true;
          exclude_retention_policy_tag = true;
          content_encoding = "gzip";
        };
      };
    };
  };

  users.users.telegraf.extraGroups = ["docker"];
  systemd.services.telegraf.after = ["tailscaled.service"];
}
