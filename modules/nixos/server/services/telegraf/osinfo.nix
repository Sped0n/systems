{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = config.services.my-telegraf;
in
{
  config = lib.mkIf cfg.enable {
    systemd = {
      tmpfiles.rules = [ "d /var/log/nixos-info 0755 telegraf telegraf -" ];
      services = {
        nixos-info-update = {
          description = "Generate a unified system info file for Telegraf";
          wantedBy = [ "multi-user.target" ];
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
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "telegraf";
            Group = "telegraf";

            ProtectSystem = "strict";
            ReadWritePaths = [ "/var/log/nixos-info" ];

            NoNewPrivileges = true;
            PrivateTmp = true;
          };
        };

        telegraf = {
          requires = [ "nixos-info-update.service" ];
          after = [ "nixos-info-update.service" ];
        };
      };
    };

    services.my-telegraf.extraConfig = {
      inputs.tail = [
        {
          files = [ "/var/log/nixos-info/nixos-info.log" ];
          name_override = "info_system";
          initial_read_offset = "beginning";
          watch_method = "inotify";
          data_format = "logfmt";
          tags = {
            metric_type = "logs";
            log_source = "telegraf";
          };
        }
      ];
      outputs.loki = [
        {
          domain = "http://100.96.0.${vars."srv-de-0".meshId}:9428";
          endpoint = "/insert/loki/api/v1/push";
          gzip_request = true;
          sanitize_label_names = true;
          namepass = [ "info_system" ];
        }
      ];
    };
  };
}
