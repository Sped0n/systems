{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:

let
  my-restic = config.services.my-restic;
  my-telegraf = config.services.my-telegraf;
in
{
  options.services.my-restic = {
    enable = lib.mkEnableOption "Whether to enable the custom Restic backup module.";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Directories that should be included in the Restic backup.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Exclude rules applied to the Restic backup.";
    };

    pruneOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional prune options passed to Restic.";
    };

    backupPrepareCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = "Command executed before the backup runs.";
    };

    backupCleanupCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = "Command executed after the backup finishes.";
    };
  };

  config = lib.mkIf my-restic.enable {
    age.secrets =
      let
        owner = "root";
        mode = "0400";
      in
      {
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
        repository = "s3:s3.eu-central-003.backblazeb2.com/spedon-infra-backup/${config.networking.hostName}";
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
        paths = my-restic.paths;
        exclude = my-restic.exclude;
        pruneOpts = my-restic.pruneOpts;
      }
      // lib.optionalAttrs (my-restic.backupPrepareCommand != null) {
        backupPrepareCommand = my-restic.backupPrepareCommand;
      }
      // lib.optionalAttrs (my-restic.backupCleanupCommand != null) {
        backupCleanupCommand = my-restic.backupCleanupCommand;
      };
    };

    users = {
      users.restic-notify = {
        isSystemUser = true;
        group = "restic-notify";
        extraGroups = [
          "systemd-journal"
          "smtp-auth-users"
        ];
      };
      groups.restic-notify = { };
    };

    systemd.services = {
      "restic-backups-main".onFailure = [ "restic-failure-notify.service" ];
      "restic-failure-notify" = {
        description = "Notify on Restic backup failure";
        path = with pkgs; [
          coreutils
          systemd
          msmtp
        ];
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

          KeyringMode = "private";
        };
      };
    };

    services.my-telegraf.syslogExtraFilters.ignore_restic_noise = lib.mkIf my-telegraf.enable ''
      not (program("restic") and level(info));
    '';
  };
}
