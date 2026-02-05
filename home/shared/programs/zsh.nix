{
  functions,
  lib,
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    completionInit = "autoload -Uz compinit && compinit";
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };
    syntaxHighlighting = {
      enable = true;
    };
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        source ${(functions.fromRoot "/home/raw/zsh/extras.zsh")}
        source ${(functions.fromRoot "/home/raw/zsh/functions.zsh")}
      '')
      (lib.mkOrder 1550 "fastfetch")
    ];
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
    };
    plugins = [
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];
  };
}
