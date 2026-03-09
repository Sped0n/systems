{ pkgs, ... }:
{
  home.keyboard = {
    layout = "us";
    variant = "";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        rime-data
        fcitx5-gtk
        fcitx5-rime
      ];
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys"."0" = "Control+space";
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

  dconf.settings."org/gnome/shell".enabled-extensions = [
    "kimpanel@kde.org"
  ];
}
