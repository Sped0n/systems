{ ... }:
{
  programs.ghostty = {
    enable = true;
    systemd.enable = false;
    settings = {
      font-family = "Lilex Medium";
      keybind = [
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
