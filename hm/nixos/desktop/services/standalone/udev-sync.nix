{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.services.standalone.enable {
    home.activation.checkUdevRules = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [[ ! -e /etc/NIXOS ]]; then
        # Inspect the incoming generation, not a possibly stale user profile.
        for rule in ${config.home.path}/lib/udev/rules.d/*.rules; do
          [[ -e "$rule" ]] || continue
          source=$(${pkgs.coreutils}/bin/readlink -e "$rule")
          destination="/etc/udev/rules.d/''${rule##*/}"
          installed=$(${pkgs.coreutils}/bin/readlink -e "$destination" || true)
          if [[ "$installed" != "$source" ]]; then
            warnEcho "Packaged udev rules are missing or outdated (''${rule##*/})."
            warnEcho "To link the current rules and reload udev, run:"
            warnEcho "  udev-sync"
            break
          fi
        done
      fi
    '';

    home.packages = [
      (pkgs.writeShellApplication {
        name = "udev-sync";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          dry_run=false
          case "''${1:-}" in
            --dry-run) dry_run=true ;;
            "") ;;
            *) echo "Usage: udev-sync [--dry-run]" >&2; exit 2 ;;
          esac
          if (( $# > 1 )); then
            echo "Usage: udev-sync [--dry-run]" >&2
            exit 2
          fi
          if [[ -e /etc/NIXOS ]]; then
            echo "On NixOS, use services.udev.packages instead." >&2
            exit 1
          fi

          shopt -s nullglob
          rules=(${lib.escapeShellArg config.home.profileDirectory}/lib/udev/rules.d/*.rules)
          if (( ''${#rules[@]} == 0 )); then
            echo "No udev rules found in the Home Manager profile."
            exit 0
          fi

          sources=()
          destinations=()
          for rule in "''${rules[@]}"; do
            source=$(readlink -e "$rule")
            if [[ "$source" != /nix/store/* || ! -f "$source" ]]; then
              echo "Refusing rule outside the Nix store: $rule" >&2
              exit 1
            fi
            destination="/etc/udev/rules.d/''${rule##*/}"
            if [[ -e "$destination" || -L "$destination" ]]; then
              target=$(readlink "$destination" || true)
              # Update Nix-store links or adopt identical copied rules, but
              # never overwrite a differing administrator-maintained rule.
              if [[ "$target" != /nix/store/* ]] && ! cmp -s "$source" "$destination"; then
                echo "Conflicting local rule: $destination; move it aside first." >&2
                exit 1
              fi
            fi
            sources+=("$source")
            destinations+=("$destination")
            printf '%s -> %s\n' "$destination" "$source"
          done

          if [[ "$dry_run" == true ]]; then
            exit 0
          fi
          command -v sudo >/dev/null
          command -v udevadm >/dev/null
          sudo -v
          sudo install -d -m 0755 /etc/udev/rules.d
          for i in "''${!sources[@]}"; do
            sudo ln -sfnT -- "''${sources[$i]}" "''${destinations[$i]}"
          done
          sudo udevadm control --reload-rules
          echo "Rules linked and reloaded. Reconnect devices to apply them."
        '';
      })
    ];
  };
}
