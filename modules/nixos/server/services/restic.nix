{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}: {
  options._services.restic = {
    enable = lib.mkEnableOption "a custom Restic backup configuration with daily backups, weekly checks, and failure notifications";
  };

  config = lib.mkIf config._services.restic.enable {
    age.secrets = let
      owner = "root";
      mode = "0400";
    in {
      "restic-env" = {
        inherit owner mode;
        file = "${secrets}/ages/restic-env.age";
      };

      "restic-password" = {
        inherit owner mode;
        file = "${secrets}/ages/restic-password.age";
      };
    };

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

    users.users.restic-notify = {
      isSystemUser = true;
      group = "restic-notify";
      extraGroups = [
        "systemd-journal"
        "smtp-auth-users"
      ];
    };
    users.groups.restic-notify = {};

    systemd.services = {
      "restic-backups-main".onFailure = ["restic-failure-notify.service"];
      "restic-failure-notify" = {
        description = "Notify on Restic backup failure";
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
        serviceConfig = {
          Type = "oneshot";
          User = "restic-notify";
          Group = "restic-notify";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          BindReadOnlyPaths = [
            "/etc/msmtprc"
            config.age.secrets."smtp-password".path
          ];

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
