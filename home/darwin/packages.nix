{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker
    minicom
    cdecl
    bfg-repo-cleaner
    repomix
    hyperfine
    ast-grep

    smartmontools
    restic
    pandoc

    ffmpeg
    imagemagick
  ];
}
