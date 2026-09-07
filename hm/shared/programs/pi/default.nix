{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  configDir = "${config.xdg.configHome}/pi";
  tiers = builtins.fromJSON (builtins.readFile ./tiers.json);

  mkSymlink = path: {
    "${configDir}/${path}".source =
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/hm/shared/programs/pi/${path}";
  };
in
{
  options.programs.my-pi.enable = mkEnableOption "Pi coding agent";

  config = mkIf config.programs.my-pi.enable {
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
          (builtins.fromJSON (builtins.readFile ./settings.json))
          // {
            defaultProvider = tiers.default.provider;
            defaultModel = tiers.default.model;
            defaultThinkingLevel = tiers.default.thinkingLevel;
            # Pi treats this as the last viewed release, suppressing the startup changelog.
            lastChangelogVersion = pkgs.llm-agents.pi.version;
          }
        );
      }
      (mkSymlink "AGENTS.md")
      (mkSymlink "keybindings.json")
      (mkSymlink "models.json")
      (mkSymlink "tiers.json")
      (mkSymlink "interceptor.json")
      (mkSymlink "extensions")
      (mkSymlink "skills")
      (mkSymlink "themes")
    ];
  };
}
