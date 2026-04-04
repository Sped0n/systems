{
  lib,
  pkgs,
  vars,
  ...
}:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/.config 0755 ${username} users -"
    "d ${home}/.local/state/systems-sync 0755 ${username} users -"
  ];

  system.activationScripts.systems-sync = {
    deps = [ "users" ];
    text = ''
      if ! /run/wrappers/bin/su - ${vars.username} -s ${pkgs.bash}/bin/bash -c ${lib.escapeShellArg "${
        (pkgs.writeShellScript "systems-sync-activation" ''
          TARGET="${vars.home}/.config/systems"
          REPO="https://github.com/Sped0n/systems.git"
          STATE_DIR="${vars.home}/.local/state/systems-sync"
          LOCK_FILE="$STATE_DIR/sync.lock"
          TIMESTAMP_FILE="$STATE_DIR/last-update"
          NVIM_BIN="/etc/profiles/per-user/${vars.username}/bin/nvim"
          NOW="$(${pkgs.coreutils}/bin/date +%s)"
          WARN_YELLOW='\033[1;33m'
          WARN_RESET='\033[0m'
          CHANGED=0
          LAZY_LOCK_CHANGED=0

          mkdir -p "$STATE_DIR" "$(dirname "$TARGET")"

          if [ -f "$TIMESTAMP_FILE" ]; then
            LAST_UPDATE="$(${pkgs.coreutils}/bin/cat "$TIMESTAMP_FILE" 2>/dev/null || printf '0')"
            if [ -n "$LAST_UPDATE" ] && [ $((NOW - LAST_UPDATE)) -lt 3600 ]; then
              echo "systems-sync: last update was less than one hour ago, skipping"
              exit 0
            fi
          fi

          exec 9>"$LOCK_FILE"
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            echo "systems-sync: another sync is already running, skipping"
            exit 0
          fi

          if [ -d "$TARGET/.git" ]; then
            cd "$TARGET"

            OLD_HEAD="$(git rev-parse HEAD 2>/dev/null || printf 'missing')"
            OLD_LAZY_LOCK="$(git rev-parse HEAD:lazy-lock.json 2>/dev/null || printf 'missing')"
            CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || printf "")"
            if [ "$CURRENT_REMOTE" != "$REPO" ]; then
              echo "systems-sync: updating remote URL to $REPO"
              git remote set-url origin "$REPO" || true
            fi

            if [ -n "$(git status --porcelain)" ]; then
              echo "systems-sync: repository is dirty, performing hard reset"
              git reset --hard || true
            fi

            echo "systems-sync: pulling from remote"
            if ! git pull --ff-only >/dev/null 2>&1; then
              printf '%bsystems-sync: warning: git pull failed%b\n' "$WARN_YELLOW" "$WARN_RESET"
            fi

            NEW_HEAD="$(git rev-parse HEAD 2>/dev/null || printf 'missing')"
            if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
              CHANGED=1
              NEW_LAZY_LOCK="$(git rev-parse HEAD:lazy-lock.json 2>/dev/null || printf 'missing')"
              if [ "$OLD_LAZY_LOCK" != "$NEW_LAZY_LOCK" ]; then
                LAZY_LOCK_CHANGED=1
              fi
            fi
          elif [ -d "$TARGET" ]; then
            echo "systems-sync: replacing non-git directory at $TARGET"
            rm -rf "$TARGET"
            git clone "$REPO" "$TARGET" || true
            if [ -d "$TARGET/.git" ]; then
              CHANGED=1
              LAZY_LOCK_CHANGED=1
            fi
          else
            echo "systems-sync: cloning repository into $TARGET"
            git clone "$REPO" "$TARGET" || true
            if [ -d "$TARGET/.git" ]; then
              CHANGED=1
              LAZY_LOCK_CHANGED=1
            fi
          fi

          if [ "$CHANGED" = "1" ]; then
            printf '%s\n' "$NOW" > "$TIMESTAMP_FILE"
            if [ -x "$NVIM_BIN" ]; then
              if [ "$LAZY_LOCK_CHANGED" = "1" ]; then
                echo "systems-sync: starting neovim lazy restore"
                if ! HOME="${vars.home}" \
                  XDG_CONFIG_HOME="${vars.home}/.config" \
                  "$NVIM_BIN" --headless '+LazyRestoreNoLockOverwrite' '+qa' >/dev/null 2>&1; then
                  printf '%bsystems-sync: warning: neovim lazy restore failed%b\n' "$WARN_YELLOW" "$WARN_RESET"
                fi
              fi

              echo "systems-sync: starting treesitter sync"
              if ! HOME="${vars.home}" \
                XDG_CONFIG_HOME="${vars.home}/.config" \
                "$NVIM_BIN" --headless '+TSSync' '+qa' >/dev/null 2>&1; then
                printf '%bsystems-sync: warning: neovim treesitter sync failed%b\n' "$WARN_YELLOW" "$WARN_RESET"
              fi
            else
              echo "systems-sync: neovim binary not found at $NVIM_BIN, skipping restore"
            fi
          fi
        '')
      }"}; then
        printf '\033[1;33msystems-sync: warning: activation sync failed\033[0m\n'
      fi
    '';
  };
}
