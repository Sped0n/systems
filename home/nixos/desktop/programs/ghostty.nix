{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Lilex Medium";
      font-size = 11;
      keybind = [
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
