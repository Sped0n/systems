{
  config,
  pkgs,
  vars,
  home,
  ...
}: let
  sourceDir = "${home}/infra/data";
  composeFile = "${home}/infra/docker-compose.yml";
  serviceConfig = {
    Type = "oneshot";
    User = "root";
    EnvironmentFile = config.age.secrets."restic-env".path;
    TimeoutStartSec = "15m";
  };
  keepDaily = 3;
  keepWeekly = 2;
in {
  systemd.services."restic-backup" = {
    description = "Stop services, run Restic backup for ${sourceDir}, restart services";
    inherit serviceConfig;
    environment = {
      RESTIC_REPOSITORY = "s3:s3.eu-central-003.backblazeb2.com/${vars.backupBucketName}/tennousei";
      RESTIC_PASSWORD_FILE = "${config.age.secrets."restic-password".path}";
    };
    script = ''
      set -euo pipefail # Exit on error, unset variable, or pipe failure

      echo "Attempting to stop Docker Compose services from ${composeFile}..."
      # Use the full path provided by the pkgs.docker package
      ${pkgs.docker}/bin/docker compose -f "${composeFile}" stop
      echo "Docker Compose services stopped."

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

      # --- Restart Docker Compose ---
      echo "Attempting to start Docker Compose services from ${composeFile}..."
      ${pkgs.docker}/bin/docker compose -f "${composeFile}" start
      echo "Docker Compose services started."

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
    inherit serviceConfig;
    environment = {
      RESTIC_REPOSITORY = "s3:s3.eu-central-003.backblazeb2.com/${vars.backupBucketName}/tennousei";
      RESTIC_PASSWORD_FILE = "${config.age.secrets."restic-password".path}";
    };
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
