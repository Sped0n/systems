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
      tio

      popsicle
    ])
    ++ (with pkgs-unstable; [
      gimp3-with-plugins
      onlyoffice-desktopeditors

      obsidian
    ]);
}
