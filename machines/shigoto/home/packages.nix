{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages =
    (
      with pkgs;
      # Dev tools
        [
          android-tools
        ]
        ++
        # Desktop apps
        [
          teams-for-linux

          popsicle
          peazip
        ]
    )
    ++ (
      with pkgs-unstable;
      # Dev tools
        [
          beekeeper-studio
          imhex
        ]
        ++
        # Productivity
        [
          obsidian
        ]
    );
}
