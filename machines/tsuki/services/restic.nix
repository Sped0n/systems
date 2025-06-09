{
  pkgs,
  config,
  vars,
  home,
  ...
}: let
  sourceDir = "${home}/infra";
  composeFile = "${home}/infra/docker-compose.yml";
  serviceConfig = {
    Type = "oneshot";
    User = "root";
    EnvironmentFile = config.age.secrets."restic-env".path;
    TimeoutStartSec = "15m";
  };
  environment = {
    RESTIC_REPOSITORY =
      "s3:s3.eu-central-003.backblazeb2.com/"
      + "${vars.backupBucketName}/${config.networking.hostName}";
    RESTIC_PASSWORD_FILE = "${config.age.secrets."restic-password".path}";
  };
  keepDaily = 3;
  keepWeekly = 2;
in {
  systemd = {
    services = {
      "restic-backup" = {
        description = "Stop services, run Restic backup for ${sourceDir}, restart services";
        inherit serviceConfig environment;
        onFailure = ["restic-backup-failure-notify.service"];
        script = ''
          set -euo pipefail

          echo "Attempting to stop related services..."
          systemctl stop beszel-hub.service
          ${pkgs.docker}/bin/docker compose -f "${composeFile}" stop
          echo "Related services stopped."

          echo "Starting Restic backup for ${sourceDir}..."
          ${pkgs.restic}/bin/restic backup \
            --exclude="*.log" \
            --verbose \
            --tag daily \
            --tag systemd-timer \
            "${sourceDir}"
          echo "Backup finished."

          echo "Applying retention policy (keep ${toString keepDaily} daily, ${toString keepWeekly} weekly)..."
          ${pkgs.restic}/bin/restic forget \
            --verbose \
            --keep-daily ${toString keepDaily} \
            --keep-weekly ${toString keepWeekly} \
            --prune
          echo "Restic prune complete."

          echo "Attempting to start related services..."
          systemctl start beszel-hub.service
          ${pkgs.docker}/bin/docker compose -f "${composeFile}" start
          echo "Related services started."

          echo "Restic backup process complete for ${sourceDir}."
        '';
      };

      "restic-backup-failure-notify" = {
        description = "Notify admin about restic backup failure";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = ''
          {
            echo "From: Infrastructure <${vars.infraEmail}>"
            echo "To: ${vars.personalEmail}"
            echo "Subject: [ALERT] Restic Backup Failed"
            echo
            echo "Restic backup failed on ${config.networking.hostName} at $(${pkgs.coreutils}/bin/date)."
            echo
            echo "Below is the result of the \`journalctl -u restic-backup.service -n 30 --no-pager\`:"
            echo "-----------------------------------------------------------------------"
            journalctl -u restic-backup.service -n 30 --no-pager
            echo "-----------------------------------------------------------------------"
          } | ${pkgs.msmtp}/bin/sendmail -t
        '';
      };

      "restic-check" = {
        description = "Restic repository health check";
        inherit serviceConfig environment;
        script = ''
          set -euo pipefail
          echo "Starting Restic repository check..."
          ${pkgs.restic}/bin/restic check
          echo "Restic repository check complete."
        '';
      };
    };

    timers = {
      "restic-backup" = {
        description = "Daily timer for Restic backup of ${sourceDir}";
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

  environment.systemPackages = let
    restic-wrapper = pkgs.writeShellScriptBin "restic-wrapper" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      if [[ "$EUID" -ne 0 ]]; then
        echo "Error: This script must be run as root. Please use sudo." >&2
        exit 1
      fi

      export $(${pkgs.coreutils}/bin/cat "${config.age.secrets."restic-env".path}" | ${pkgs.findutils}/bin/xargs)
      export RESTIC_REPOSITORY="${environment.RESTIC_REPOSITORY}"
      export RESTIC_PASSWORD_FILE="${environment.RESTIC_PASSWORD_FILE}"

      echo "--- Restic Wrapper: executing with preset environment ---" >&2
      exec env "${pkgs.restic}/bin/restic" "$@"
    '';
  in [restic-wrapper];
}
