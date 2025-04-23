{
  config,
  pkgs,
  vars,
  home,
  ...
}: let
  sourceDir = "${home}/infra/data";
  serviceConfig = {
    Type = "oneshot";
    User = "root";
    EnvironmentFile = config.age.secrets."restic-env".path;
    TimeoutStartSec = "15m";
  };
  environment = {
    RESTIC_REPOSITORY = "s3:s3.eu-central-003.backblazeb2.com/${vars.backupBucketName}/tsuki";
    RESTIC_PASSWORD_FILE = "${config.age.secrets."restic-password".path}";
  };
  keepDaily = 3;
  keepWeekly = 2;
in {
  systemd.services."restic-backup" = {
    description = "Stop services, run Restic backup for ${sourceDir}, restart services";
    inherit serviceConfig environment;
    script = ''
      set -euo pipefail # Exit on error, unset variable, or pipe failure

      echo "Attempting to stop related services..."
      systemctl stop beszel-hub.service
      echo "Related services stopped."

      # --- Restic Backup ---
      echo "Starting Restic backup for ${sourceDir}..."
      ${pkgs.restic}/bin/restic backup \
        --exclude="*.log" \
        --verbose \
        --tag daily \
        --tag systemd-timer \
        "${sourceDir}"
      echo "Backup finished."

      # --- Restic Prune ---
      echo "Applying retention policy (keep ${toString keepDaily} daily, ${toString keepWeekly} weekly)..."
      ${pkgs.restic}/bin/restic forget \
        --verbose \
        --keep-daily ${toString keepDaily} \
        --keep-weekly ${toString keepWeekly} \
        --prune
      echo "Restic prune complete."

      # --- Restart Related Services ---
      echo "Attempting to start related services..."
      systemctl start beszel-hub.service
      echo "Related services started."

      echo "Restic backup process complete for ${sourceDir}."
    '';
  };

  systemd.timers."restic-backup" = {
    description = "Daily timer for Restic backup of ${sourceDir}";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      Unit = "restic-backup.service";
    };
  };

  systemd.services."restic-check" = {
    description = "Restic repository health check";
    inherit serviceConfig environment;
    script = ''
      set -euo pipefail
      echo "Starting Restic repository check..."
      ${pkgs.restic}/bin/restic check
      echo "Restic repository check complete."
    '';
  };

  systemd.timers."restic-check" = {
    description = "Weekly timer for Restic repository check";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      Unit = "restic-check.service";
    };
  };
}
