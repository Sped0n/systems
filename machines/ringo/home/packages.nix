{pkgs, ...}: {
  home.packages = with pkgs; [
    docker
    minicom
    cdecl

    smartmontools

    ffmpeg
    imagemagick
  ];
}
