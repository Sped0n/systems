{
  config,
  lib,
  pkgs,
  ...
}:
let
  nixos-deploy = config.programs.nixos-deploy;
in
{
  options.programs.nixos-deploy.enable = lib.mkEnableOption "nixos multi-host deploy helper";

  config = lib.mkIf nixos-deploy.enable {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "nixos-deploy";
        runtimeInputs = with pkgs; [
          nixos-rebuild-ng
          python3
        ];
        text = ''
          set -euo pipefail

          usage() {
            cat <<'EOF'
          Usage:
            nixos-deploy <flake> <target-host>
            nixos-deploy <flake> <build-host> <target-host>

          Notes:
            - Remaining nixos-rebuild arguments are fixed by this wrapper.
            - Provide sudo password via stdin if you want non-interactive execution.
          EOF
          }

          if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
            usage >&2
            exit 1
          fi

          flake="$1"
          if [ "$#" -eq 2 ]; then
            build_host=""
            target_host="$2"
          else
            build_host="$2"
            target_host="$3"
          fi

          cmd=(nixos-rebuild-ng switch --flake "$flake")
          if [ -n "$build_host" ]; then
            cmd+=(--build-host "$build_host")
          fi
          cmd+=(
            --target-host "$target_host"
            --sudo
            --ask-sudo-password
            --use-substitutes
          )

          echo "Running: ''${cmd[*]}"
          python3 -c '
          import os
          import signal
          import subprocess
          import sys

          proc = subprocess.Popen(sys.argv[1:], preexec_fn=os.setsid)
          signal.signal(signal.SIGINT, lambda sig, _frame: os.killpg(proc.pid, sig))
          signal.signal(signal.SIGTERM, lambda sig, _frame: os.killpg(proc.pid, sig))
          sys.exit(proc.wait())
          ' "''${cmd[@]}"
        '';
      })
    ];
  };
}
