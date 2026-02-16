{
  config,
  lib,
  pkgs-unstable,
  secrets,
  ...
}:
let
  hostname = config.networking.hostName;
  my-docker = config.services.my-docker;
  my-runner = config.services.my-runner;
  tokenFilePath = config.age.secrets."forgejo-runner-token".path;
in
{
  options.services.my-runner = {
    enable = lib.mkEnableOption "Whether to enable the custom Forgejo Runner module.";

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "docker:docker://catthehacker/ubuntu:act-latest"
      ];
      description = "Labels advertised by this runner.";
    };

    capacity = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Maximum concurrent jobs.";
    };

    dockerOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--memory=4g"
        "--memory-swap=8g"
        "--cpus=3"
      ];
      description = "Extra docker run options.";
    };

    cacheMaxSizeInGib = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
      description = ''
        Maximum allowed size (in GiB) for the runner cache directory.

        If the directory grows beyond this limit, a daily check will:
        stop the runner unit, delete the cache dir (reset purge),
        then start the runner unit again.
      '';
      example = 50;
    };
  };

  config = lib.mkIf my-runner.enable {
    assertions = [
      {
        assertion = (!my-runner.enable) || my-docker.enable;
        message = "services.my-runner.enable requires services.my-docker.enable = true";
      }
    ];

    age.secrets."forgejo-runner-token" = {
      file = "${secrets}/ages/forgejo-runner-token.age";
      owner = "root";
      mode = "0400";
    };

    services.gitea-actions-runner = {
      package = pkgs-unstable.forgejo-runner;
      instances.default = {
        enable = true;
        name = "${hostname}";
        tokenFile = tokenFilePath;
        url = "https://git.sped0n.com/";
        labels = my-runner.labels;
        settings = {
          runner = {
            capacity = my-runner.capacity;
            fetch_interval = "30s";
          };
          container = {
            docker_host = "automount";
            options = lib.concatStringsSep " " my-runner.dockerOptions;
            force_pull = true;
          };
        };
      };
    };

    networking.firewall.trustedInterfaces = [ "br-+" ];

    systemd = {
      services.runner-cache-purge = {
        description = "Purge Forgejo runner actcache if it exceeds configured size";
        serviceConfig = {
          User = "root";
          Group = "root";
          Type = "oneshot";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "full";
          ProtectHome = true;
          PrivateDevices = true;

          PrivateNetwork = true;
          RestrictAddressFamilies = [ "AF_UNIX" ];
          SystemCallArchitectures = "native";
          UMask = "0077";

          ExecStart = (
            pkgs-unstable.writeShellScript "runner-cache-purge" ''
              set -euo pipefail

              CACHEDIR=${lib.escapeShellArg "/var/lib/gitea-runner/default/.cache/actcache"}
              RUNNER_UNIT=${lib.escapeShellArg "gitea-runner-default.service"}
              LIMIT_GIB=${toString my-runner.cacheMaxSizeInGib}

              LOCKDIR=/run/lock
              LOCKFILE="$LOCKDIR/runner-cache-purge.lock"
              mkdir -p "$LOCKDIR"

              exec 9>"$LOCKFILE"
              ${pkgs-unstable.util-linux}/bin/flock -n 9 || exit 0

              if [ ! -d "$CACHEDIR" ]; then
                exit 0
              fi

              size_bytes="$(${pkgs-unstable.coreutils}/bin/du -sb "$CACHEDIR" | ${pkgs-unstable.coreutils}/bin/cut -f1)"
              limit_bytes="$(( LIMIT_GIB * 1024 * 1024 * 1024 ))"

              if [ "$size_bytes" -le "$limit_bytes" ]; then
                exit 0
              fi

              echo "runner cache purge: $CACHEDIR is ''${size_bytes} bytes (> ''${limit_bytes}); purging by reset"

              was_active=0
              if /run/current-system/sw/bin/systemctl is-active --quiet "$RUNNER_UNIT"; then
                was_active=1
                /run/current-system/sw/bin/systemctl stop "$RUNNER_UNIT"
              fi

              ${pkgs-unstable.coreutils}/bin/rm -rf -- "$CACHEDIR"

              if [ "$was_active" -eq 1 ]; then
                /run/current-system/sw/bin/systemctl start "$RUNNER_UNIT"
              fi

              echo "runner cache purge: done"
            ''
          );
          TimeoutStartSec = "30min";
        };
      };

      timers.runner-cache-purge = {
        description = "Daily check for Forgejo runner actcache size";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 03:30:00";
          Persistent = true;
          RandomizedDelaySec = "15min";
          Unit = "runner-cache-purge.service";
        };
      };
    };
  };
}
