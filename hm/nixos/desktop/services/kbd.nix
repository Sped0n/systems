{ config, pkgs, ... }:
{
  home = {
    keyboard = {
      layout = "us";
      variant = "";
    };
    packages = with pkgs; [
      gnomeExtensions.kimpanel
    ];
    sessionVariables = {
      XMODIFIERS = "@im=fcitx";
    };

    file.".config/systemd/user/org.freedesktop.IBus.session.GNOME.service".source =
      config.lib.file.mkOutOfStoreSymlink "/dev/null";
  };

  dconf.settings."org/gnome/shell".enabled-extensions = [
    "kimpanel@kde.org"
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        rime-ice
        fcitx5-gtk
        fcitx5-rime
      ];
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys"."0" = "Menu";
          Behavior = {
            ActiveByDefault = false;
            resetStateWhenFocusIn = "No";
            ShareInputState = "No";
            PreeditEnabledByDefault = true;
            ShowInputMethodInformation = true;
            showInputMethodInformationWhenFocusIn = false;
            CompactInputMethodInformation = true;
            ShowFirstInputMethodInformation = true;
            DefaultPageSize = 5;
            OverrideXkbOption = false;
            PreloadInputMethod = true;
            AllowInputMethodForPassword = false;
            ShowPreeditForPassword = false;
            AutoSavePeriod = 30;
          };
        };
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "rime";
            Layout = "";
          };
        };
      };
    };
  };
}
