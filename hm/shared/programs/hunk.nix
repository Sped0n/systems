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
    home.packages = [ pkgs.hunk ];

    xdg.configFile."hunk/config.toml".source = toml.generate "hunk-config.toml" {
      theme = "custom";
      mode = "auto";
      line_numbers = true;
      wrap_lines = true;
      agent_notes = true;

      custom_theme = {
        base = "graphite";
        label = "Kanagawa Dragon";
        background = "#181616";
        panel = "#181616";
        panelAlt = "#181616";
        border = "#2d4f67";
        accent = "#c8c093";
        accentMuted = "#8ba4b0";
        text = "#c5c9c5";
        muted = "#a6a69c";
        addedBg = "#293829";
        removedBg = "#3f2525";
        contextBg = "#181616";
        movedAddedBg = "#8ba4b0";
        movedRemovedBg = "#8ba4b0";
        addedContentBg = "#385038";
        removedContentBg = "#6a3030";
        contextContentBg = "#181616";
        addedSignColor = "#87a987";
        removedSignColor = "#e46876";
        lineNumberBg = "#0d0c0c";
        lineNumberFg = "#a6a69c";
        selectedHunk = "#2d4f67";
        badgeAdded = "#87a987";
        badgeRemoved = "#e46876";
        badgeNeutral = "#a6a69c";
        fileNew = "#87a987";
        fileDeleted = "#e46876";
        fileRenamed = "#e6c384";
        fileModified = "#c8c093";
        fileUntracked = "#7fb4ca";
        noteBorder = "#a292a3";
        noteBackground = "#241d24";
        noteTitleBackground = "#322832";
        noteTitleText = "#c5c9c5";

        syntax = {
          default = "#c5c9c5";
          keyword = "#938aa9";
          string = "#87a987";
          comment = "#a6a69c";
          number = "#e6c384";
          function = "#7fb4ca";
          property = "#8ba4b0";
          type = "#c4b28a";
          punctuation = "#8ea4a2";
        };
      };
    };
  };
}
