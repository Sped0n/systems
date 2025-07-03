{...}: {
  programs.git = {
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

    ignores = [".DS_Store" "*.swp" ".direnv"];

    delta = {
      enable = true;
      options = {
        line-number = true;
        dark = true;
        navigate = true;
        syntax-theme = "ansi";
      };
    };

    aliases = {
      diff-side-by-side = "-c delta.features=side-by-side diff";
    };
  };
}
