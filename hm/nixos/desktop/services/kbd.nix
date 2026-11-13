{
  config,
  lib,
  pkgs,
  ...
}:
let
  rimeAddon = pkgs.fcitx5-rime.override {
    rimeDataPkgs = with pkgs; [
      rime-data
      rime-ice
    ];
  };
in
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

  # Keep the existing file-level links when migrating the Rime configuration.
  xdg.configFile.fcitx5.recursive = true;

  xdg.dataFile = {
    "fcitx5/rime/default.custom.yaml".text = ''
      patch:
        schema_list:
          - schema: rime_ice
    '';

    "fcitx5/rime/rime_ice.custom.yaml".text = ''
      patch:
        "switches/@2/reset": 0
    '';
  };

  systemd.user.services.fcitx5-daemon = {
    Unit.X-Restart-Triggers = [
      config.xdg.dataFile."fcitx5/rime/default.custom.yaml".source
      config.xdg.dataFile."fcitx5/rime/rime_ice.custom.yaml".source
    ];
    Service = {
      ExecStartPre = lib.escapeShellArgs [
        (lib.getExe (
          pkgs.writeShellApplication {
            name = "deploy-rime";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              rimeDir="$1"
              mkdir -p "$rimeDir/build"
              # Store-backed YAML has old timestamps; invalidate only its compiled configs.
              rm -f -- "$rimeDir/build/default.yaml" "$rimeDir/build/rime_ice.schema.yaml"
              ${pkgs.librime}/bin/rime_deployer --build "$rimeDir" ${rimeAddon}/share/rime-data "$rimeDir/build"
              test -s "$rimeDir/build/default.yaml"
              test -s "$rimeDir/build/rime_ice.schema.yaml"
            '';
          }
        ))
        "${config.xdg.dataHome}/fcitx5/rime"
      ];
      TimeoutStartSec = "5min";
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [
        pkgs.fcitx5-gtk
        rimeAddon
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
