{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.my-pi;
  configDir = "${config.xdg.configHome}/pi";

  mkSymlink = path: {
    "${configDir}/${path}".source =
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/hm/shared/programs/pi/${path}";
  };
in
{
  options.programs.my-pi = {
    enable = mkEnableOption "Pi coding agent";
    pcommit = {
      enable = mkEnableOption "Pi commit message generation" // {
        default = true;
      };
      provider = mkOption {
        type = types.str;
        default = "circe";
        description = "Provider used to generate commit messages.";
      };
      model = mkOption {
        type = types.str;
        default = "gpt-6.1-sol";
        description = "Model used to generate commit messages.";
      };
      thinking = mkOption {
        type = types.enum [
          "off"
          "minimal"
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ];
        default = "low";
        description = "Thinking level used to generate commit messages.";
      };
    };
    pcontrol.enable = mkEnableOption "Pi session control" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.uv.enable = true;

    age.secrets = {
      "circe-api-key" = {
        file = "${secrets}/ages/circe-api-key.age";
        mode = "0400";
      };
      "jina-api-key" = {
        file = "${secrets}/ages/jina-api-key.age";
        mode = "0400";
      };
    };

    home.packages = import ./wrapper.nix {
      inherit
        config
        configDir
        lib
        pkgs
        ;
    };

    home.file = lib.mkMerge [
      (mkSymlink "settings.json")
      (mkSymlink "AGENTS.md")
      (mkSymlink "models.json")
      (mkSymlink "interceptor.json")
      (mkSymlink "extensions")
      (mkSymlink "skills")
    ];
  };
}
