{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      docker
      minicom
      cdecl
      bfg-repo-cleaner

      smartmontools
    ])
    ++ (with pkgs-unstable; [
      repomix
      hyperfine
      ast-grep

      restic
      pandoc

      ffmpeg
      imagemagick
    ]);
}
