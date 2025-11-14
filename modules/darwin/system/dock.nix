{ ... }:
{
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
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
      appswitcher-all-displays = true; # Show app switcher on all displays
      mru-spaces = false; # Automatically rearrange Spaces based on most recent use
    };

    CustomUserPreferences.".GlobalPreferences".AppleSpacesSwitchOnActivate = true; # Automatically switch to a new space when switching to the application
  };
}
