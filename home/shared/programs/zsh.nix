{pkgs, ...}: {
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
    initExtraFirst = "
      source ${../config/zsh/extras.zsh}
      source ${../config/zsh/functions.zsh}
    ";
    initExtra = "fastfetch";
    plugins = [
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];
  };
}
