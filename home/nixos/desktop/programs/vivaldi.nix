{ pkgs-unstable, ... }:
{
  programs.vivaldi.enable = true;

  home.packages = with pkgs-unstable; [
    vivaldi-ffmpeg-codecs
  ];
}
