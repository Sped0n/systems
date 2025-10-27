{ ... }:
{
  programs = {
    git = {
      enable = true;
      lfs.enable = true;

      userName = "Sped0n";
      userEmail = "hi@sped0n.com";

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        merge.conflictStyle = "zdiff3";
        core.editor = "nvim";
      };

      signing = {
        key = "059FB9EB7BC658BB";
        format = "openpgp";
        signByDefault = true;
      };

      ignores = [
        ".DS_Store"
        "*.swp"
        ".direnv"
      ];

      delta = {
        enable = true;
        options = {
          line-number = true;
          dark = true;
          navigate = true;
          syntax-theme = "ansi";
          diff-so-fancy = true;
        };
      };

      aliases = {
        diff-side-by-side = "-c delta.features=side-by-side diff";
      };
    };

    zsh.shellAliases = {
      "gis" = "git status";
      "glo" =
        "git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --branches";
      "grsh1" = ''
        git --no-pager log -1 --pretty=format:"%C(bold yellow)Commit message about to be reset:%n%C(reset)%B" &&
        git reset --soft HEAD~1
      '';
      "gai" = "git add -i && git status";
      "gsu" = "git submodule update --init --recursive --progress";
    };
  };
}
