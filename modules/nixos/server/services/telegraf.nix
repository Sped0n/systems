{
  pkgs,
  pkgs-unstable,
  config,
  ...
}: {
  services = {
    telegraf = {
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
              name_override = "info_kernel_version";
              commands = ["${pkgs.coreutils}/bin/uname -r"];
              interval = "15m";
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
            ignore_protocol_stats = true;
          };
          netstat = {};
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
          processes = {};
          syslog = {
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
            tags = {
              metric_type = "logs";
              log_source = "telegraf";
            };
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
              "processes*"
            ];
          };
          loki = [
            {
              domain = "http://tsuki:9428";
              endpoint = "/insert/loki/api/v1/push";
              gzip_request = true;
              sanitize_label_names = true;
              namepass = [
                "info*"
                "syslog*"
              ];
            }
          ];
        };
      };
    };

    journald.forwardToSyslog = true;

    syslog-ng = {
      enable = true;
      extraConfig = ''
        source s_src {
          system();
        };

        destination d_telegraf {
          syslog("127.0.0.1" port(6514));
        };

        filter f_skip_docker_containers {
          not program("docker#*");
        };

        filter f_basic {
          program("sshd") or (
              not program("sshd") and level(notice..emerg)
          );
        };

        log {
          source(s_src);
          filter(f_skip_docker_containers);
          filter(f_basic);
          destination(d_telegraf);
        };
      '';
    };
  };

  users.users.telegraf.extraGroups = ["docker"];
  systemd.services = {
    telegraf.after = ["tailscaled.service"];
    syslog-ng.after = ["telegraf.service"];
  };
}
