{...}:
###################################################################################
#
#  macOS's System configuration
#
#  All the configuration options are documented here:
#    https://daiderd.com/nix-darwin/manual/index.html#sec-options
#  Incomplete list of macOS `defaults` commands :
#    https://github.com/yannbertrand/macos-defaults
#
###################################################################################
{
  system = {
    stateVersion = 6;
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      menuExtraClock.Show24Hour = true;

      dock = {
        autohide = true;
        show-recents = true;
        persistent-apps = [
          {
            app = "/System/Applications/iPhone Mirroring.app";
          }
        ];
        wvous-tl-corner = 5; # top-left - Start Screen Saver
        wvous-tr-corner = 1; # top-right - Disabled
        wvous-bl-corner = 1; # bottom-left - Disabled
        wvous-br-corner = 4; # bottom-right - Desktop
      };

      finder = {
        ShowPathbar = true; # Show path bar
        ShowStatusBar = true; # Show status bar
        FXPreferredViewStyle = "clmv"; # Set finder default view style to column
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };

      # customize settings that not supported by nix-darwin directly
      # Incomplete list of macOS `defaults` commands :
      #   https://github.com/yannbertrand/macos-defaults
      NSGlobalDomain = {
        "com.apple.trackpad.scaling" = 1.6; # Configures the trackpad tracking speed (0 to 3).

        "com.apple.sound.beep.feedback" = 0; # Disable beep sound when pressing volume up/down key

        AppleKeyboardUIMode = 3; # Mode 3 enables full keyboard control
        InitialKeyRepeat = 15; # Normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        KeyRepeat = 3; # Normal minimum is 2 (30 ms), maximum is 120 (1800 ms)
        "com.apple.keyboard.fnState" = true; # Use F1, F2, etc. keys as standard function keys
        NSAutomaticCapitalizationEnabled = false; # Disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false; # Disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false; # Disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false; # Disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false; # Disable auto spelling correction
        NSNavPanelExpandedStateForSaveMode = true; # Expand save panel by default
        NSNavPanelExpandedStateForSaveMode2 = true;
      };

      # Customize settings that not supported by nix-darwin directly
      # see the source code of this project to get more undocumented options:
      #    https://github.com/rgcr/m-cli
      #
      # All custom entries can be found by running `defaults read` command.
      # or `defaults read xxx` to read a specific domain.
      CustomUserPreferences = {
        ".GlobalPreferences" = {
          # Automatically switch to a new space when switching to the application
          AppleSpacesSwitchOnActivate = true;
        };
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };
        "com.apple.finder" = {
          ShowHardDrivesOnDesktop = false;
          ShowExternalHardDrivesOnDesktop = true;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
          _FXSortFoldersFirst = true;
          # When performing a search, search the current folder by default
          FXDefaultSearchScope = "SCcf";
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.screensaver" = {
          # Require password immediately after sleep or screen saver begins
          askForPassword = 1;
          askForPasswordDelay = 0;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        # Prevent Photos from opening automatically when devices are plugged in
        "com.apple.ImageCapture".disableHotPlug = true;
      };

      loginwindow = {
        GuestEnabled = false; # disable guest user
        SHOWFULLNAME = true; # show full name in login window
      };
    };
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
}
