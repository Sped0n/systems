{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      bfg-repo-cleaner
      cdecl
      tio

      ffmpeg
      imagemagick
      pandoc
      restic

      peazip
    ])
    ++ (with pkgs-unstable; [
      repomix
      hyperfine
      ast-grep

      httpie-desktop
      obsidian
      gimp3-with-plugins
      onlyoffice-desktopeditors
    ]);
}
