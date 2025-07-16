{
  pkgs,
  pkgs-unstable,
  config,
  ...
}: {
  systemd = {
    tmpfiles.rules = ["d /var/log/nixos-info 0755 root telegraf -"];

    services.nixos-info-update = {
      description = "Generate a unified system info file for Telegraf";
      serviceConfig.Type = "oneshot";
      path = with pkgs; [
        fastfetch
        jq
        coreutils
        diffutils
      ];
      script = ''
        set -e

        FILE_PATH="/var/log/nixos-info/nixos-info.log"

        update_if_changed() {
          local new_content="$1"
          touch "$FILE_PATH"
          if ! echo "$new_content" | cmp -s - "$FILE_PATH"; then
            echo "System info is outdated. Updating $FILE_PATH."
            echo "$new_content" > "$FILE_PATH"
          fi
        }

        CPU_RAW=$(
          fastfetch --structure 'CPU' --format json | \
          jq -r '.[0].result | "\(.cpu) (\(.cores.physical))"'
        )
        KERNEL_RAW=$(uname -r)
        OS_RAW=$(
          fastfetch --structure 'OS' --format json | \
          jq -r '.[0].result | "\(.prettyName)"'
        )

        FINAL_LINE="cpu_model=\"$CPU_RAW\" kernel_version=\"$KERNEL_RAW\" os_name=\"$OS_RAW\""

        update_if_changed "$FINAL_LINE"
      '';
    };

    timers.nixos-info-update = {
      description = "Timer to generate Telegraf info file after boot";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1min";
        Persistent = false;
        Unit = "nixos-info-update.service";
      };
    };
  };

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

        inputs = let
          logTags = {
            metric_type = "logs";
            log_source = "telegraf";
          };
        in {
          system = {};
          kernel.collect = ["psi"];
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
            tags = logTags;
          };
          tail = [
            {
              files = ["/var/log/nixos-info/nixos-info.log"];
              name_override = "info_system";
              initial_read_offset = "beginning";
              watch_method = "inotify";
              data_format = "logfmt";
              tags = logTags;
            }
          ];
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

        filter f_ignore_firewall {
            not (
              program("kernel") and
              level(info) and
              message("refused connection:")
            );
        };

        filter f_ignore_veth {
            not (
              program("kernel") and
              level(info) and
              message("veth")
            );
        };

        filter f_basic {
            (
                (program("tailscaled") or program("dhcpcd")) and
                level(notice..emerg)
            )
            or
            (
                not (program("tailscaled") or program("dhcpcd")) and
                level(info..emerg)
            )
        };

        log {
          source(s_src);
          filter(f_skip_docker_containers);
          filter(f_ignore_firewall);
          filter(f_ignore_veth);
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
