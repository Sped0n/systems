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
      cachix

      repomix
      hyperfine
      ast-grep

      httpie-desktop
      bitwarden-desktop
      obsidian
      gimp3-with-plugins
      onlyoffice-desktopeditors
    ]);
}
