{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{
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
        source ${../config/zsh/extras.zsh}
        source ${../config/zsh/functions.zsh}
      '')
      (lib.mkOrder 1500 ''
        export OPENAI_API_KEY=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."openai-api-key".path})
        export CODESTRAL_API_KEY=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."codestral-api-key".path})
      '')
      (lib.mkOrder 1550 "fastfetch")
    ];
    shellAliases = {
      "gis" = "git status";
      "glo" =
        "git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --branches";
      "grsh1" = "git reset --soft HEAD~1";
      "gai" = "git add -i && git status";
      "gsu" = "git submodule update --init --recursive --progress";
      "exl" = "exa -l";
      "exaa" = "exa -a";
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
