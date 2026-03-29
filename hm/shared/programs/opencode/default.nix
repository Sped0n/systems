{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  imports = [
    ./wrappers
  ];

  programs.opencode = {
    enable = lib.mkDefault false;
    package = pkgs.llm-agents.opencode;
  };

  xdg.configFile =
    let
      mkOpencodeSymlink = path: {
        "opencode/${path}".source =
          config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/hm/shared/programs/opencode/config/${path}";
      };
    in
    lib.mkIf opencode.enable (
      lib.mkMerge [
        (mkOpencodeSymlink "opencode.jsonc")
        (mkOpencodeSymlink "tui.jsonc")
        (mkOpencodeSymlink "AGENTS.md")
        (mkOpencodeSymlink "agents")
        (mkOpencodeSymlink "skills")
        (mkOpencodeSymlink "instructions")
        (mkOpencodeSymlink "plugins")
      ]
    );
}
