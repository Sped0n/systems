{ vars, ... }:
{
  system.defaults.CustomSystemPreferences."/Library/Preferences/com.apple.TimeMachine" = {
    # This list replaces the fixed-path exclusions configured in Time Machine.
    SkipPaths =
      # Caches and downloaded packages.
      [
        "/Users/${vars.username}/Library/Caches"
        "/Users/${vars.username}/.cache"
        "/Users/${vars.username}/.npm"
        "/Users/${vars.username}/.local/share"
        "/Users/${vars.username}/go"
      ]
      # Reinstallable stores, toolchains, and environments.
      ++ [
        "/nix/store"
        "/Users/${vars.username}/.rustup"
        "/Users/${vars.username}/.espressif"
      ]
      # Container runtime data.
      ++ [
        "/Users/${vars.username}/Library/Application Support/com.apple.container"
      ]
      # Downloaded wallpapers and media artwork.
      ++ [
        "/Users/${vars.username}/Library/Containers/com.apple.wallpaper.extension.aerials"
        "/Users/${vars.username}/Library/Containers/com.apple.AMPArtworkAgent"
        "/Users/${vars.username}/Library/Application Support/com.apple.wallpaper"
      ];
  };
}
