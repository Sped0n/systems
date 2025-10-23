{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    (with pkgs; [
      android-tools
      popsicle
      cdecl
    ])
    ++ (with pkgs-unstable; [
      teams-for-linux
      obsidian
      gimp3-with-plugins
      libreoffice-qt6-fresh
    ]);
}
