{
  config,
  home,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codegpt;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.programs.codegpt = {
    enable = mkEnableOption "CodeGPT";

    diffUnified = mkOption {
      type = types.int;
      default = 5;
      description = "Number of lines for unified diff context in git.";
      example = 5;
    };

    model = lib.mkOption {
      type = types.str;
      default = "openai/gpt-4.1-mini";
      description = "The OpenAI model to use.";
      example = "openai/gpt-4.1-mini";
    };

    temperature = lib.mkOption {
      type = types.str;
      default = "0.9";
      description = "The sampling temperature to use (as a string).";
      example = "0.9";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../pkgs/codegpt.nix { })
    ];

    xdg.configFile = {
      "codegpt/.codegpt.yaml" = {
        source = yamlFormat.generate "codegpt-config" {
          git = {
            diff_unified = cfg.diffUnified;
            exclude_list = "";
            template_file = "";
            template_string = "";
          };
          openai = {
            api_key = "";
            api_version = "";
            base_url = "https://openrouter.ai/api/v1";
            headers = "HTTP-Referer=https://github.com/appleboy/CodeGPT X-Title=CodeGPT";
            max_tokens = 300;
            model = cfg.model;
            org_id = "";
            provider = "openai";
            proxy = "";
            skip_verify = false;
            socks = "";
            temperature = cfg.temperature;
            timeout = "30s";
          };
          output = {
            file = "";
            lang = "en";
          };
          prompt = {
            folder = "${home}/.config/codegpt/prompt";
          };
        };
      };

      "codegpt/prompt/conventional_commit.tmpl".source =
        ../../shared/config/codegpt/conventional_commit.tmpl;
      "codegpt/prompt/summarize_file_diff.tmpl".source =
        ../../shared/config/codegpt/summarize_file_diff.tmpl;
    };
  };
}
