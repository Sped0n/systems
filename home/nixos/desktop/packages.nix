{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      cdecl
      minicom

      restic
      pandoc
      peazip

      ffmpeg
      imagemagick
    ])
    ++ (with pkgs-unstable; [
      bitwarden-desktop
      obsidian
      gimp3-with-plugins
      onlyoffice-desktopeditors

      repomix
      hyperfine
      ast-grep
    ]);
}
