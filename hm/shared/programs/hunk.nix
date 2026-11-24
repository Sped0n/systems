{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.hunk;
  toml = pkgs.formats.toml { };
in
{
  options.programs.hunk.enable = lib.mkEnableOption "Hunk diff viewer";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.llm-agents.hunk ];

    xdg.configFile."hunk/config.toml".source = toml.generate "hunk-config.toml" {
      theme = "kanagawa-dragon";
      mode = "auto";
      line_numbers = true;
      wrap_lines = true;
      agent_notes = true;
    };
  };
}
