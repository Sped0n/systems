{...}: {
  system.defaults = {
    finder = {
      ShowPathbar = true; # Show path bar
      ShowStatusBar = true; # Show status bar
      FXPreferredViewStyle = "clmv"; # Set finder default view style to column
    };

    NSGlobalDomain = {
      NSNavPanelExpandedStateForSaveMode = true; # Expand save panel by default
      AppleShowAllExtensions = true; # Show all file extensions in Finder
    };

    CustomUserPreferences = {
      "com.apple.finder" = {
        ShowHardDrivesOnDesktop = false;
        ShowExternalHardDrivesOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        _FXSortFoldersFirst = true;
        FXDefaultSearchScope = "SCcf"; # When performing a search, search the current folder by default
      };
      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
    };
  };
}
