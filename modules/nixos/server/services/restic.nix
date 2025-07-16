{
  lib,
  config,
  pkgs,
  vars,
  ...
}: {
  options._services.restic = {
    enable = lib.mkEnableOption "a custom Restic backup configuration with daily backups, weekly checks, and failure notifications";
  };

  config = lib.mkIf config._services.restic.enable {
    services.restic.backups = {
      "main" = {
        user = "root";
        repository = "s3:s3.eu-central-003.backblazeb2.com/${vars.backupBucketName}/${config.networking.hostName}";
        passwordFile = config.age.secrets."restic-password".path;
        environmentFile = config.age.secrets."restic-env".path;
        extraBackupArgs = [
          "--verbose"
          "--tag daily"
          "--tag systemd-timer"
        ];
        initialize = true;
        runCheck = true;
        createWrapper = true;
        timerConfig = {
          OnCalendar = "*-*-* 03:00:00";
          Persistent = true;
        };
      };
    };

    systemd.services = {
      "restic-backups-main".onFailure = ["restic-failure-notify.service"];
      "restic-failure-notify" = {
        description = "Notify on Restic backup failure";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = with pkgs; [coreutils systemd msmtp];
        script = ''
          {
            echo "From: Infrastructure <${vars.infraEmail}>"
            echo "To: ${vars.personalEmail}"
            echo "Subject: [ALERT] Restic job failed on ${config.networking.hostName}"
            echo
            echo "Restic job failed at $(date)."
            echo "Journal logs:"
            echo "-----------------------------------------------------------------------"
            journalctl -u restic-backups-main -n 30 --no-pager
            echo "-----------------------------------------------------------------------"
          } | sendmail -t
        '';
      };
    };
  };
}
