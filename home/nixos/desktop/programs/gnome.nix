{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    gnomeExtensions.appindicator
  ];

  dconf = {
    enable = true;
    settings = with lib.hm.gvariant; {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
        ];
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "brave-browser.desktop"
          "com.mitchellh.ghostty.desktop"
          "teams-for-linux.desktop"
        ];
      };

      "org/gnome/desktop/input-sources" = {
        mru-sources = [(mkTuple ["xkb" "us"]) (mkTuple ["ibus" "rime"])];
        sources = [(mkTuple ["xkb" "us"]) (mkTuple ["ibus" "rime"])];
        xkb-options = ["grp:caps_toggle"];
      };

      "org/gnome/desktop/wm/keybindings" = {
        switch-input-source = [];
        switch-input-source-backward = [];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>space";
        command = "albert toggle";
        name = "albert";
      };
    };
  };
}
