{ config, lib, pkgs, ... }:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  inherit (common)
    builder
    containerBin
    launchAgentsDir
    runtimeLabel
    user
    ;

  builderLabel = "dev.apple.container.${builder.name}";
  builderPlist = "${launchAgentsDir}/${builderLabel}.plist";
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
          builder_label=${lib.escapeShellArg builderLabel}
          builder_plist=${lib.escapeShellArg builderPlist}
          builder_name=${lib.escapeShellArg builder.name}
          builder_image=${lib.escapeShellArg cfg.image}

          usage() {
            printf 'usage: my-linux-builder {start|stop|restart|update|status|test-ssh}\n' >&2
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
            bootstrap_or_kickstart "$builder_label" "$builder_plist"
          }

          stop_builders() {
            require_domain
            stop_label "$builder_label"
            stop_label "$runtime_label"
            ${containerBin} stop "$builder_name" >/dev/null 2>&1 || true
            ${containerBin} rm "$builder_name" >/dev/null 2>&1 || true
          }

          show_status() {
            printf 'runtime:\n'
            ${containerBin} system status || true
            printf '\ncontainers:\n'
            ${containerBin} ls --all || true
            printf '\nlaunchd:\n'
            local label
            for label in "$runtime_label" "$builder_label"; do
              if /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
                printf '%s: loaded\n' "$label"
              else
                printf '%s: not loaded\n' "$label"
              fi
            done
          }

          test_ssh() {
            failed=0
            printf '%s: ' "$builder_name"
            ssh -o BatchMode=yes -o ConnectTimeout=5 "$builder_name" uname -m || failed=1
            exit "$failed"
          }

          update_image() {
            require_domain
            if ! ${containerBin} system status >/dev/null 2>&1; then
              ${containerBin} system start --disable-kernel-install
            fi
            ${containerBin} image pull "$builder_image"
            stop_builders
            start_builders
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
            update)
              update_image
              ;;
            status)
              show_status
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
