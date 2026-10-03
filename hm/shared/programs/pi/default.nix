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
  settings = builtins.fromJSON (builtins.readFile ./settings.json);

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
        default = "circe-responses";
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
      {
        "${configDir}/settings.json".text = builtins.toJSON (
          settings
          // {
            extensions =
              (settings.extensions or [ ])
              ++ lib.optional (!cfg.pcommit.enable) "-extensions/pcommit/index.ts"
              ++ lib.optional (!cfg.pcontrol.enable) "-extensions/control/index.ts";
            # Pi treats this as the last viewed release, suppressing the startup changelog.
            lastChangelogVersion = pkgs.llm-agents.pi.version;
          }
        );
      }
      (mkSymlink "AGENTS.md")
      (mkSymlink "keybindings.json")
      (mkSymlink "models.json")
      (mkSymlink "interceptor.json")
      (mkSymlink "extensions")
      (mkSymlink "skills")
    ];
  };
}
