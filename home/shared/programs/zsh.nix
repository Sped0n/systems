{
  lib,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
    completionInit = "autoload -Uz compinit && compinit";
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = ["history" "completion"];
    };
    syntaxHighlighting = {
      enable = true;
    };
    initContent = lib.mkMerge [
      (
        lib.mkOrder 500 ''
          source ${../config/zsh/extras.zsh}
          source ${../config/zsh/functions.zsh}
        ''
      )
      (lib.mkOrder 1500 "fastfetch")
    ];
    plugins = [
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];
  };
}
