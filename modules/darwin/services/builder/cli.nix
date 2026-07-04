{ config, lib, pkgs, ... }:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  inherit (common)
    containerBin
    enabledArches
    launchAgentsDir
    runtimeLabel
    user
    ;

  builderNames = lib.mapAttrsToList (_: arch: arch.name) enabledArches;
  builderLabels = lib.mapAttrsToList (_: arch: "dev.apple.container.${arch.name}") enabledArches;
  builderPlists = lib.mapAttrsToList (_: arch: "${launchAgentsDir}/dev.apple.container.${arch.name}.plist") enabledArches;
  sshTests = lib.concatMapStringsSep "\n" (name: ''
    printf '%s: ' ${lib.escapeShellArg name}
    if ssh -o BatchMode=yes -o ConnectTimeout=5 ${lib.escapeShellArg name} uname -m; then
      :
    else
      failed=1
    fi
  '') builderNames;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "my-linux-builder";
        runtimeInputs = [ pkgs.openssh ];
        text = ''
          set -euo pipefail

          uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg user})"
          domain="user/$uid"
          runtime_label=${lib.escapeShellArg runtimeLabel}
          runtime_plist=${lib.escapeShellArg "${launchAgentsDir}/${runtimeLabel}.plist"}
          builder_labels=(${lib.concatMapStringsSep " " lib.escapeShellArg builderLabels})
          builder_plists=(${lib.concatMapStringsSep " " lib.escapeShellArg builderPlists})
          builder_names=(${lib.concatMapStringsSep " " lib.escapeShellArg builderNames})

          usage() {
            printf 'usage: my-linux-builder {start|stop|restart|status|logs|test-ssh}\n' >&2
          }

          require_domain() {
            if ! /bin/launchctl print "$domain" >/dev/null 2>&1; then
              printf 'launchd domain %s is not available\n' "$domain" >&2
              exit 1
            fi
          }

          bootstrap_or_kickstart() {
            local label="$1"
            local plist="$2"

            if /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
              /bin/launchctl kickstart -k "$domain/$label"
            else
              /bin/launchctl bootstrap "$domain" "$plist"
              /bin/launchctl enable "$domain/$label" >/dev/null 2>&1 || true
            fi
          }

          stop_label() {
            local label="$1"
            /bin/launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
          }

          start_builders() {
            require_domain
            if ! ${containerBin} system status >/dev/null 2>&1; then
              ${containerBin} system start --disable-kernel-install
            fi
            bootstrap_or_kickstart "$runtime_label" "$runtime_plist"
            local i
            for i in "''${!builder_labels[@]}"; do
              bootstrap_or_kickstart "''${builder_labels[$i]}" "''${builder_plists[$i]}"
            done
          }

          stop_builders() {
            require_domain
            local label name
            for label in "''${builder_labels[@]}"; do
              stop_label "$label"
            done
            stop_label "$runtime_label"
            for name in "''${builder_names[@]}"; do
              ${containerBin} stop "$name" >/dev/null 2>&1 || true
              ${containerBin} rm "$name" >/dev/null 2>&1 || true
            done
          }

          show_status() {
            printf 'runtime:\n'
            ${containerBin} system status || true
            printf '\ncontainers:\n'
            ${containerBin} ls --all || true
            printf '\nlaunchd:\n'
            local label
            for label in "$runtime_label" "''${builder_labels[@]}"; do
              if /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
                printf '%s: loaded\n' "$label"
              else
                printf '%s: not loaded\n' "$label"
              fi
            done
          }

          show_logs() {
            /usr/bin/tail -n 80 \
              "$HOME/Library/Logs/$runtime_label.err" \
              "$HOME/Library/Logs/''${builder_labels[0]}.err" \
              "$HOME/Library/Logs/''${builder_labels[1]}.err" 2>/dev/null || true
          }

          test_ssh() {
            failed=0
            ${sshTests}
            exit "$failed"
          }

          case "''${1:-}" in
            start)
              start_builders
              ;;
            stop)
              stop_builders
              ;;
            restart)
              stop_builders
              start_builders
              ;;
            status)
              show_status
              ;;
            logs)
              show_logs
              ;;
            test-ssh)
              test_ssh
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
