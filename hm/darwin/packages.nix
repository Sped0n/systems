{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      bfg-repo-cleaner
      cdecl
      docker
      minicom

      ffmpeg
      imagemagick
      pandoc
      restic
      smartmontools
    ])
    ++ (with pkgs-unstable; [
      cachix

      repomix
      hyperfine
      ast-grep
    ]);
}
