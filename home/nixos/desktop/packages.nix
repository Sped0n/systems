{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      bfg-repo-cleaner
      cdecl
      minicom

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
      httpie

      bitwarden-desktop
      obsidian
      gimp3-with-plugins
      onlyoffice-desktopeditors
    ]);
}
