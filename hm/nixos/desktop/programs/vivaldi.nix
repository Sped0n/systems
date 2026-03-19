{ pkgs-unstable, ... }:
{
  programs.vivaldi = {
    enable = true;
    package = pkgs-unstable.vivaldi.override {
      enableWidevine = true;
      proprietaryCodecs = true;
      vivaldi-ffmpeg-codecs = pkgs-unstable.vivaldi-ffmpeg-codecs;
    };
  };
}
