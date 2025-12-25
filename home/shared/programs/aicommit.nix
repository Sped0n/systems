{
  config,
  functions,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  cfg = config.programs.aichat;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "aicommit";
        runtimeInputs = [
          pkgs.git
          pkgs.coreutils
          pkgs-unstable.aichat
        ];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          hint="''${1:-}"

          if git diff --cached --quiet; then
            echo "No staged changes."
            exit 0
          fi

          temp_message_file="$(mktemp -t aicommit-msg.XXXXXX)"
          trap 'rm -f "$temp_message_file"' EXIT

          recent_commits="$(
            git log -n 5 --pretty=format:$'- %s%n%b%n' 2>/dev/null || true
          )"
          if [[ -z "$recent_commits" ]]; then
            recent_commits="(no previous commits to learn from yet)"
          fi

          {
            printf 'Recent commit messages (newest first):\n%s\n' "$recent_commits"
            if [[ -n "$hint" ]]; then
              printf '\nHint:\n%s\n' "$hint"
            fi
            printf '\nStaged diff:\n'
            git diff --cached
          } | aichat -r aicommit --code >"$temp_message_file"

          echo "------------- Proposed commit message -------------"
          cat "$temp_message_file"
          echo "---------------------------------------------------"

          printf "Proceed? [y] commit  [n] abort: "
          read -r user_choice

          if [[ "$user_choice" =~ ^[Yy]$ ]]; then
            git commit -s -e -F "$temp_message_file"
          else
            echo "Aborted."
            exit 1
          fi
        '';
      })
    ];

    xdg.configFile."aichat/roles/aicommit.md".source = (
      functions.fromRoot "/home/shared/config/aichat/roles/aicommit.md"
    );
  };
}
