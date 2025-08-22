{ ... }:
{
  security.pam.services.sudo_local.touchIdAuth = true; # Add ability to used TouchID for sudo authentication

  system.defaults = {
    loginwindow = {
      GuestEnabled = false; # disable guest user
      SHOWFULLNAME = true; # show full name in login window
    };

    CustomUserPreferences = {
      "com.apple.screensaver" = {
        # Require password immediately after sleep or screen saver begins
        askForPassword = 1;
        askForPasswordDelay = 0;
      };
    };
  };
}
