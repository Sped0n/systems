{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    (with pkgs; [
      android-tools
      cdecl

      popsicle
    ])
    ++ (with pkgs-unstable; [
      gimp3-with-plugins
      onlyoffice-desktopeditors

      obsidian
    ]);
}
