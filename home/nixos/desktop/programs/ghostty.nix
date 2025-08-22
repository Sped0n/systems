{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;

      keybind = [
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
