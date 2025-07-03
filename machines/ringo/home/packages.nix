{pkgs, ...}: {
  home.packages = with pkgs; [
    docker
    minicom
    smartmontools

    ffmpeg
    imagemagick
  ];
}
