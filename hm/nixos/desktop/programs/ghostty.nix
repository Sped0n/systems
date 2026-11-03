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

  xdg.desktopEntries."com.mitchellh.ghostty" = {
    name = "Ghostty";
    exec = "ghostty --gtk-single-instance=true";
    icon = "com.mitchellh.ghostty";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    startupNotify = true;
    settings = {
      DBusActivatable = "false";
      StartupWMClass = "com.mitchellh.ghostty";
    };
    actions.new-window = {
      name = "New Window";
      exec = "ghostty --gtk-single-instance=true";
    };
  };
}
