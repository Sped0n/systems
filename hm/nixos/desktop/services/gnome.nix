{ lib, ... }:
{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "ubuntu-appindicators@ubuntu.com"
          "ding@rastersoft.com"
          "ubuntu-dock@ubuntu.com"
          "tiling-assistant@ubuntu.com"
        ];
        favorite-apps = lib.mkDefault [
          "org.gnome.Nautilus.desktop"
          "vivaldi-stable.desktop"
          "com.mitchellh.ghostty.desktop"
        ];
      };

      "org/gnome/desktop/input-sources" = with lib.hm.gvariant; {
        mru-sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
        ];
        sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
        ];
        xkb-options = [
          "caps:menu"
        ];
      };

      "org/gnome/desktop/session" = with lib.hm.gvariant; {
        idle-delay = mkUint32 1800;
      };

      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-fixed = false;
        dock-position = "BOTTOM";
        extend-height = false;
        multi-monitor = true;
      };

      "org/gnome/desktop/wm/keybindings" = {
        switch-to-workspace-left = [ ];
        switch-to-workspace-right = [ ];
        switch-input-source = [ ];
        switch-input-source-backward = [ ];
      };

      "org/gnome/shell/keybindings" = {
        show-screenshot-ui = [ "F8" ];
        screenshot-window = [ ];
        screenshot = [ ];
      };
    };
  };
}
