{ pkgs, pkgs-unstable, ... }:
{
  programs.vicinae = {
    enable = true;
    package = pkgs-unstable.vicinae;
    systemd.enable = true;
  };

  home.packages = with pkgs; [
    gnomeExtensions.vicinae
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "vicinae@dagimg-dot"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
    ];

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>space";
      command = "vicinae toggle";
      name = "albert";
    };
  };
}
