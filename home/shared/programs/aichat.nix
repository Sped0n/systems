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
    home.packages = [ pkgs-unstable.aichat ];

    xdg.configFile = {
      "aichat/config.yaml" = {
        source = yamlFormat.generate "aichat-config" {
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
      };
    };
  };
}
