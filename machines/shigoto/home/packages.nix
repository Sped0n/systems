{
  pkgs,
  pkgs-unstable,
  agenix,
  ...
}: {
  imports = [
    ../../../home/nixos/desktop/packages.nix
  ];

  home.packages =
    (with pkgs; [
      agenix.packages."${pkgs.system}".default

      # Dev tools
      android-tools

      # IM
      teams-for-linux

      # Utility
      popsicle
      peazip
    ])
    ++ (with pkgs-unstable; [
      # Dev tools
      beekeeper-studio

      # Productivity
      obsidian
    ]);
}
