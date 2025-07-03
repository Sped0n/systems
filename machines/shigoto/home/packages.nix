{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    android-tools
    imhex
    beekeeper-studio
    popsicle

    teams-for-linux

    obsidian
  ];
}
