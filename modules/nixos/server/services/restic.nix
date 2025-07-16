{
  config,
  lib,
  pkgs,
  vars,
  ...
}: let
  cfg = config.services.restic-backup;

  repository =
    "s3:s3.eu-central-003.backblazeb2.com/"
    + "${vars.backupBucketName}/${config.networking.hostName}";
  passwordFile = config.age.secrets."restic-password".path;
  environmentFile = config.age.secrets."restic-env".path;
in {
  options.services.restic-backup = {
    enable = lib.mkEnableOption "a declarative Restic backup service";

    backupDir = lib.mkOption {
      type = lib.types.str;
      description = "The absolute path to the directory to back up.";
      example = "/var/lib/data";
    };

    preBackupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "A list of shell commands to execute before the backup starts. Use extraPath to add commands to the PATH.";
      example = [
        "docke -compose -f /path/to/docker-compose.yml stop"
      ];
    };

    postBackupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "A list of shell commands to execute after the backup is complete. Use extraPath to add commands to the PATH.";
      example = [
        "docker compose -f /path/to/docker-compose.yml start"
      ];
    };

    extraPath = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "A list of packages to add to the PATH for the backup service, making their binaries available to pre/post backup commands.";
      example = lib.literalExpression "[ pkgs.docker ]";
    };

    keepDaily = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Number of daily backups to keep.";
    };

    keepWeekly = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of weekly backups to keep.";
    };
  };

  config = let
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = environmentFile;
      TimeoutStartSec = "15m";
    };

    environment = {
      RESTIC_REPOSITORY = repository;
      RESTIC_PASSWORD_FILE = passwordFile;
    };

    preBackupScript = lib.strings.concatStringsSep "\n" cfg.preBackupCommands;
    postBackupScript = lib.strings.concatStringsSep "\n" cfg.postBackupCommands;
  in
    lib.mkIf cfg.enable {
      systemd = {
        services = {
          "restic-backup" = {
            description = "Restic backup for ${cfg.backupDir}";
            inherit serviceConfig environment;
            onFailure = ["restic-backup-failure-notify.service"];
            path = (with pkgs; [coreutils restic]) ++ cfg.extraPath;
            script = ''
              set -euo pipefail

              echo "Executing pre-backup commands..."
              ${preBackupScript}
              echo "Pre-backup commands finished."

              echo "Starting Restic backup for ${cfg.backupDir}..."
              restic backup \
                --exclude="*.log" --verbose --tag daily --tag systemd-timer \
                "${cfg.backupDir}"
              echo "Backup finished."

              echo "Applying retention policy (keep ${toString cfg.keepDaily} daily, ${toString cfg.keepWeekly} weekly)..."
              restic forget \
                --verbose \
                --keep-daily ${toString cfg.keepDaily} \
                --keep-weekly ${toString cfg.keepWeekly} \
                --prune
              echo "Restic prune complete."

              echo "Executing post-backup commands..."
              ${postBackupScript}
              echo "Post-backup commands finished."
            '';
          };

          "restic-backup-failure-notify" = {
            description = "Notify admin about restic backup failure";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
            };
            path = with pkgs; [coreutils systemd msmtp];
            script = ''
              {
                echo "From: Infrastructure <${vars.infraEmail}>"
                echo "To: ${vars.personalEmail}"
                echo "Subject: [ALERT] Restic Backup Failed on ${config.networking.hostName}"
                echo
                echo "Restic backup failed at $(date)."
                echo "Journal logs for restic-backup.service:"
                echo "-----------------------------------------------------------------------"
                journalctl -u restic-backup.service -n 30 --no-pager
                echo "-----------------------------------------------------------------------"
              } | sendmail -t
            '';
          };

          "restic-check" = {
            description = "Restic repository health check";
            inherit serviceConfig environment;
            path = with pkgs; [restic];
            script = ''
              set -euo pipefail
              ${pkgs.restic}/bin/restic check
            '';
          };
        };

        timers = {
          "restic-backup" = {
            description = "Daily timer for Restic backup";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnCalendar = "*-*-* 03:00:00";
              Persistent = true;
              Unit = "restic-backup.service";
            };
          };

          "restic-check" = {
            description = "Weekly timer for Restic repository check";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnCalendar = "weekly";
              Persistent = true;
              Unit = "restic-check.service";
            };
          };
        };
      };

      environment.systemPackages = with pkgs; [
        restic

        (writeShellScriptBin "restic-wrapper" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          if [[ "$EUID" -ne 0 ]]; then
            echo "Error: This script must be run as root. Please use sudo." >&2
            exit 1
          fi
          export $(${pkgs.coreutils}/bin/cat "${environmentFile}" | ${pkgs.findutils}/bin/xargs)
          export RESTIC_REPOSITORY="${repository}"
          export RESTIC_PASSWORD_FILE="${passwordFile}"
          exec env "${pkgs.restic}/bin/restic" "$@"
        '')
      ];
    };
}
