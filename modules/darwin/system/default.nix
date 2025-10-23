{ username, ... }:
###################################################################################
#
#  macOS's System configuration
#
#  All the configuration options are documented here:
#    https://nix-darwin.github.io/nix-darwin/manual
#  Incomplete list of macOS `defaults` commands:
#    https://github.com/yannbertrand/macos-defaults
#
#  Note that any undocumented defaults have to be nested under
#  system.defaults.CustomUserPreferences, they can't just be put under
#  e.g. system.defaults.NSGlobalDomain or you will get a validation error.
#
###################################################################################
{
  imports = [
    ./finder.nix
    ./hid.nix
    ./dock.nix
    ./security.nix
  ];

  networking.hostName = "dendrobium";

  system = {
    stateVersion = 6;
    primaryUser = username;
    activationScripts.postActivation.text = ''
      # activationScripts are executed every time you boot the system or run `darwin-rebuild`.
      #
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      sudo -i -u ${username} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      menuExtraClock.Show24Hour = true;
      CustomUserPreferences = {
        NSGlobalDomain = {
          WebKitDeveloperExtras = true; # Add a context menu item for showing the Web Inspector in web views
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.ImageCapture" = {
          disableHotPlug = true; # Prevent Photos from opening automatically when devices are plugged in
        };
      };
    };
  };
}
