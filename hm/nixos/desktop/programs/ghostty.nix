{ pkgs-unstable, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs-unstable.ghostty;
    systemd.enable = false;
    settings = {
      font-family = "Lilex Medium";
      keybind = [
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
