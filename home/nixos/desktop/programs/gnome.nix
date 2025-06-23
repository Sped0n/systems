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
      };

      "org/gnome/desktop/input-sources" = {
        mru-sources = [(mkTuple ["xkb" "us"]) (mkTuple ["ibus" "rime"])];
        sources = [(mkTuple ["xkb" "us"]) (mkTuple ["ibus" "rime"])];
        xkb-options = [];
      };
    };
  };
}
