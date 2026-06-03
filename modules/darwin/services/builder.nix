{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.my-linux-builder;
  nativeLinuxSystem = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64-linux" else "x86_64-linux";
  activeSystems = if cfg.customizeVm.enable then cfg.customizeVm.systems else [ nativeLinuxSystem ];
in
{
  options.services.my-linux-builder = {
    enable = lib.mkEnableOption "Linux builder VM";

    maxJobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Maximum concurrent jobs scheduled on the builder VM.";
    };

    customizeVm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Build a custom Linux builder VM with configured resources and emulation.
          Keep this disabled for the first switch so nix-darwin can use the stock cached builder.
        '';
      };

      cores = lib.mkOption {
        type = lib.types.ints.positive;
        default = 6;
        description = "CPU cores allocated to the custom builder VM.";
      };

      memorySize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8 * 1024;
        description = "Memory allocated to the custom builder VM in MiB.";
      };

      diskSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 40 * 1024;
        description = "Maximum custom builder VM disk size in MiB.";
      };

      systems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ nativeLinuxSystem ];
        description = "Linux systems supported by the custom builder VM.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.linux-builder =
      {
        enable = true;
        ephemeral = true;
        inherit (cfg) maxJobs;
      }
      // lib.optionalAttrs cfg.customizeVm.enable {
        systems = cfg.customizeVm.systems;
        config.virtualisation = {
          cores = cfg.customizeVm.cores;
          darwin-builder = {
            inherit (cfg.customizeVm) diskSize memorySize;
          };
        };
        config.boot.binfmt.emulatedSystems = lib.remove nativeLinuxSystem cfg.customizeVm.systems;
      };

    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "my-linux-builder";
        text = ''
          set -euo pipefail

          label="org.nixos.linux-builder"
          plist="/Library/LaunchDaemons/$label.plist"

          usage() {
            printf 'usage: my-linux-builder {start|stop|restart|status|logs}\n' >&2
          }

          is_loaded() {
            sudo launchctl print "system/$label" >/dev/null 2>&1
          }

          status_summary() {
            if ! launchctl_output="$(sudo launchctl print "system/$label" 2>/dev/null)"; then
              printf 'status: stopped\n'
              printf 'label: %s\n' "$label"
              printf 'systems: ${lib.concatStringsSep ", " activeSystems}\n'
              printf 'max jobs: ${toString cfg.maxJobs}\n'
              printf 'ephemeral: true\n'
              printf 'custom vm: ${lib.boolToString cfg.customizeVm.enable}\n'
              return
            fi

            pid="$(printf '%s\n' "$launchctl_output" | awk -F '= ' '/^[[:space:]]*pid = / { print $2; exit }')"
            last_exit="$(printf '%s\n' "$launchctl_output" | awk -F '= ' '/^[[:space:]]*last exit code = / { print $2; exit }')"

            if [ -n "$pid" ]; then
              stats="$(ps -axo pid=,ppid=,pcpu=,rss= | awk -v root="$pid" '
                {
                  pid = $1
                  parent[pid] = $2
                  cpu[pid] = $3
                  rss[pid] = $4
                }
                END {
                  for (pid in parent) {
                    current = pid
                    while (current != "" && current != 0) {
                      if (current == root) {
                        totalCpu += cpu[pid]
                        totalRss += rss[pid]
                        processes += 1
                        break
                      }
                      current = parent[current]
                    }
                  }
                  printf "%.1f %d %d\n", totalCpu, totalRss, processes
                }
              ')"
              cpu="$(printf '%s\n' "$stats" | awk '{ print $1 }')"
              ram_kib="$(printf '%s\n' "$stats" | awk '{ print $2 }')"
              processes="$(printf '%s\n' "$stats" | awk '{ print $3 }')"
              ram_mib=$(( (ram_kib + 1023) / 1024 ))

              printf 'status: running\n'
              printf 'pid: %s\n' "$pid"
              printf 'processes: %s\n' "$processes"
              printf 'cpu: %s%%\n' "$cpu"
              printf 'ram: %s MiB\n' "$ram_mib"
            else
              printf 'status: loaded, not running\n'
              if [ -n "$last_exit" ]; then
                printf 'last exit: %s\n' "$last_exit"
              fi
            fi

            printf 'systems: ${lib.concatStringsSep ", " activeSystems}\n'
            printf 'max jobs: ${toString cfg.maxJobs}\n'
            printf 'ephemeral: true\n'
            printf 'custom vm: ${lib.boolToString cfg.customizeVm.enable}\n'
          }

          case "''${1:-}" in
            start)
              if is_loaded; then
                sudo launchctl kickstart "system/$label"
              else
                sudo launchctl bootstrap system "$plist"
              fi
              ;;
            stop)
              if is_loaded; then
                sudo launchctl bootout system "$plist"
              fi
              ;;
            restart)
              if is_loaded; then
                sudo launchctl kickstart -k "system/$label"
              else
                sudo launchctl bootstrap system "$plist"
              fi
              ;;
            status)
              status_summary
              ;;
            logs)
              log stream --predicate 'process == "create-builder" OR process == "run-builder" OR process CONTAINS "qemu"' --style compact
              ;;
            *)
              usage
              exit 64
              ;;
          esac
        '';
      })
    ];
  };
}
