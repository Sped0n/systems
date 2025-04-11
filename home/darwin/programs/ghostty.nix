{...}: {
  programs.ghostty = {
    enable = true;
    package = null; # currently pkgs.ghostty is marked as broken
    enableZshIntegration = true;
    settings = {
      shell-integration = "zsh";
      macos-option-as-alt = true;

      font-family = "Lilex";
      font-size = 14;
      font-thicken = true;
      font-feature = [
        "zero"
        "ss01"
        "ss04"
        "cv02"
        "cv08"
      ];
      adjust-cell-height = "10%";

      theme = "kanagawa-dragon";
      cursor-style = "bar";
      cursor-style-blink = false;
      macos-titlebar-style = "tabs";

      window-padding-x = 9;
      window-padding-y = 9;
      window-inherit-working-directory = true;

      keybind = [
        "ctrl+shift+\\=new_split:right"
        "ctrl+shift+-=new_split:down"

        "ctrl+shift+h=goto_split:left"
        "ctrl+shift+j=goto_split:bottom"
        "ctrl+shift+k=goto_split:top"
        "ctrl+shift+l=goto_split:right"

        "ctrl+shift+alt+h=resize_split:left,10"
        "ctrl+shift+alt+j=resize_split:down,10"
        "ctrl+shift+alt+k=resize_split:up,10"
        "ctrl+shift+alt+l=resize_split:right,10"

        "ctrl+shift+x=toggle_split_zoom"
      ];
    };
    themes = {
      kanagawa-dragon = {
        palette = [
          "0=#0d0c0c"
          "1=#c4746e"
          "2=#8a9a7b"
          "3=#c4b28a"
          "4=#8ba4b0"
          "5=#a292a3"
          "6=#8ea4a2"
          "7=#c8c093"
          "8=#a6a69c"
          "9=#e46876"
          "10=#87a987"
          "11=#e6c384"
          "12=#7fb4ca"
          "13=#938aa9"
          "14=#7aa89f"
          "15=#c5c9c5"
        ];
        background = "181616";
        foreground = "c5c9c5";
        cursor-color = "c8c093";
        selection-background = "2d4f67";
        selection-foreground = "c8c093";
      };
    };
  };
}
