{ pkgs, vars, ... }:
let
  repoUrl = "https://github.com/Sped0n/systems.git";
  targetDir = "${vars.home}/.config/systems";
in
{
  systemd = {
    tmpfiles.rules = with vars; [
      "d ${home}/.config 0755 ${username} users -"
    ];

    services.my-cfgpull = {
      description = "Ensure ${targetDir} is synced with ${repoUrl}";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.git ];
      serviceConfig = {
        User = vars.username;
        Group = "users";
        Type = "oneshot";
      };
      script = ''
        TARGET="${targetDir}"
        REPO="${repoUrl}"

        # Ensure the parent directory exists
        mkdir -p "$(dirname "$TARGET")"

        if [ -d "$TARGET" ]; then
          # Case: Directory exists
          
          if [ -d "$TARGET/.git" ]; then
            # Case: It is a git repository
            echo "Git repository detected at $TARGET."
            cd "$TARGET"

            # 1. Ensure Remote URL is correct
            CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
            if [ "$CURRENT_REMOTE" != "$REPO" ]; then
              echo "Remote URL mismatch (Found: $CURRENT_REMOTE). Updating to $REPO..."
              git remote set-url origin "$REPO"
            fi

            # 2. Check if dirty and reset if necessary
            if [ -n "$(git status --porcelain)" ]; then
              echo "Repository is dirty. Performing hard reset..."
              git reset --hard
            fi

            # 3. Pull latest changes
            echo "Pulling from remote..."
            git pull
          else
            # Case: Directory exists but is NOT a git repository
            echo "Directory exists but is not a git repository. Deleting and re-cloning..."
            rm -rf "$TARGET"
            git clone "$REPO" "$TARGET"
          fi

        else
          # Case: Directory does not exist
          echo "Directory not found. Cloning..."
          git clone "$REPO" "$TARGET"
        fi
      '';
    };

    timers.my-cfgpull = {
      wantedBy = [ "timers.target" ];
      partOf = [ "my-cfgpull.service" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
