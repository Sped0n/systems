{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  cfg = config.programs.aichat;
  inherit (lib) mkEnableOption mkIf types;
  yamlFormat = pkgs.formats.yaml { };

  aicommitScript = pkgs.writeShellApplication {
    name = "aicommit";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
      pkgs-unstable.aichat
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      if git diff --cached --quiet; then
        echo "No staged changes."
        exit 0
      fi

      temp_message_file="$(mktemp -t aicommit-msg.XXXXXX)"
      trap 'rm -f "$temp_message_file"' EXIT

      git diff --cached | aichat -r aicommit >"$temp_message_file"

      echo "------------- Proposed commit message -------------"
      cat "$temp_message_file"
      echo "---------------------------------------------------"

      printf "Proceed? [y] commit  [n] abort: "
      read -r user_choice

      if [[ "$user_choice" =~ ^[Yy]$ ]]; then
        git commit -s -e -F "$temp_message_file"
      else
        echo "Aborted."
        exit 1
      fi
    '';
  };
in
{
  options.programs.aichat = {
    enable = mkEnableOption "aichat";

    model = lib.mkOption {
      type = types.str;
      default = "openai/gpt-4.1-mini";
      description = "The OpenAI model to use.";
      example = "openai/gpt-4.1-mini";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs-unstable.aichat
      aicommitScript
    ];

    xdg.configFile = {
      "aichat/config.yaml".source = yamlFormat.generate "aichat-config" {
        model = "openai:${cfg.model}";
        keybinding = "vi";
        highlight = true;
        light_theme = false;
        clients = [
          {
            type = "openai";
            api_base = "https://openrouter.ai/api/v1";
          }
        ];
      };
      "aichat/roles/aicommit.md".source = ../config/aichat/roles/aicommit.md;
    };

    programs.zsh.shellAliases."aicommit" = "${aicommitScript}/bin/aicommit";
  };
}
