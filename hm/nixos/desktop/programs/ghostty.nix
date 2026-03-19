{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Lilex Medium";
      keybind = [
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
