{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.git-extras
  ];

  programs = {
    git = {
      enable = true;
      lfs.enable = true;

      settings = {
        user = {
          name = "Sped0n";
          email = "hi@sped0n.com";
        };
        alias = {
          diff-side-by-side = "-c delta.features=side-by-side diff";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        merge.conflictStyle = "zdiff3";
        core.editor = "nvim";
        hook.require-prek = {
          event = "pre-commit";
          command = "${pkgs.writeShellScript "require-prek-hook" ''
            if [ ! -f .pre-commit-config.yaml ] || ! command -v prek >/dev/null 2>&1; then
              exit 0
            fi

            hook="$(${config.programs.git.package}/bin/git rev-parse --git-path hooks/pre-commit)"
            if [ ! -x "$hook" ]; then
              printf '%s\n' 'Pre-commit hook missing. Run: prek install' >&2
              exit 1
            fi
          ''}";
        };
      };

      signing = {
        key = "059FB9EB7BC658BB";
        format = "openpgp";
        signByDefault = true;
      };

      ignores = [
        ".DS_Store"
        "*.swp"
        "__pycache__/"
      ];
    };

    zsh.shellAliases = {
      "gis" = "git status";
      "glo" =
        "git log --color --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      "grsh1" = ''
        git --no-pager log -1 --pretty=format:"%C(bold yellow)Commit message about to be reset:%n%C(reset)%B" &&
        git reset --soft HEAD~1
      '';
      "gai" = "git add -i && git status";
      "gsu" = "git submodule update --init --recursive --progress";
      "gsync" = "git commit -sm \"sync $(date +\"%Y%m%d%H%M\")\"";
    };
  };
}
