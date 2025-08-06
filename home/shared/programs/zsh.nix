{
  config,
  lib,
  pkgs,
  secrets,
  ...
}: {
  age.secrets = {
    "openai-api-key" = {
      file = "${secrets}/ages/openai-api-key.age";
      mode = "0400";
    };
    "codestral-api-key" = {
      file = "${secrets}/ages/codestral-api-key.age";
      mode = "0400";
    };
  };

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
    shellAliases = {
      "gis" = "git status";
      "gilo" = "git log --oneline";
      "exl" = "exa -l";
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
    sessionVariables = {
      OPENAI_API_KEY = "$(${pkgs.coreutils}/bin/cat ${config.age.secrets."openai-api-key".path})";
      CODESTRAL_API_KEY = "$(${pkgs.coreutils}/bin/cat ${config.age.secrets."codestral-api-key".path})";
    };
  };
}
