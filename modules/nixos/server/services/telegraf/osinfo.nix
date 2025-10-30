{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.my-telegraf;
in
{
  config = lib.mkIf cfg.enable {
    users = {
      users.nixos-info-updater = {
        isSystemUser = true;
        group = "nixos-info-updater";
      };
      groups.nixos-info-updater = { };
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/log/nixos-info 0755 nixos-info-updater nixos-info-updater -"
      ];
      services.nixos-info-update = {
        description = "Generate a unified system info file for Telegraf";
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.fastfetch
          pkgs.jq
          pkgs.coreutils
          pkgs.diffutils
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
          User = "nixos-info-updater";
          Group = "nixos-info-updater";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [ "/var/log/nixos-info" ];

          NoNewPrivileges = true;
          LockPersonality = true;
          RestrictSUIDSGID = true;

          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;

          KeyringMode = "private";
          RemoveIPC = true;
          RestrictRealtime = true;
        };
      };
    };
  };
}
