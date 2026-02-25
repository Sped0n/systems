{
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    gnomeExtensions.appindicator
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
        ];
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "vivaldi-stable.desktop"
          "com.mitchellh.ghostty.desktop"
          "teams-for-linux.desktop"
        ];
      };

      "org/gnome/desktop/input-sources" = with lib.hm.gvariant; {
        mru-sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
          (mkTuple [
            "ibus"
            "rime"
          ])
        ];
        sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
          (mkTuple [
            "ibus"
            "rime"
          ])
        ];
        xkb-options = [ "grp:caps_toggle" ];
      };

      "org/gnome/desktop/wm/keybindings" = {
        switch-input-source = [ ];
        switch-input-source-backward = [ ];
      };
    };
  };
}
