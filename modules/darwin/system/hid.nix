{ ... }:
{
  system.defaults = {
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

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
    };

    CustomUserPreferences = {
      "com.apple.HIToolbox" = {
        AppleFnUsageType = 2; # Press globe key to <Show Emoji & Symbols>
        AppleEnabledInputSources = [
          {
            "Bundle ID" = "com.apple.inputmethod.SCIM";
            "Input Mode" = "com.apple.inputmethod.SCIM.ITABC";
            InputSourceKind = "Input Mode";
          }
          {
            "Bundle ID" = "com.apple.CharacterPaletteIM";
            InputSourceKind = "Non Keyboard Input Method";
          }
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = -2;
            "KeyboardLayout Name" = "US Extended";
          }
          {
            "Bundle ID" = "com.apple.PressAndHold";
            InputSourceKind = "Non Keyboard Input Method";
          }
          {
            "Bundle ID" = "com.apple.inputmethod.SCIM";
            InputSourceKind = "Keyboard Input Method";
          }
        ];
      };

      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "32".enabled = false; # Mission Control
          "163".enabled = false; # Show Notification Center
          "175".enabled = false; # Turn Do Not Disturb on/off
          "33".enabled = false; # Application windows
          "36".enabled = false; # Show Desktop
          "222".enabled = false; # Turn Stage Manager on/off
          "79".enabled = false; # Move left a space
          "81".enabled = false; # Move right a space

          "60".enabled = false; # Select the previous input source
          "61".enabled = false; # Select next source in input menu

          "28".enabled = false; # Save picture of screen as a file
          "29".enabled = false; # Copy picture of screen to the clipboard
          "30".enabled = false; # Save picture of selected area as file
          "31".enabled = false; # Copy picture of selected area to the clipboard
          "184".enabled = true; # Screenshot and recording options

          "64".enabled = false; # Show Spotlight search
          "65".enabled = true; # Show Finder search window
        };
      };
    };
  };
}
