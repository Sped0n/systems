{pkgs, ...}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  home.packages = with pkgs;
    [
      docker
      minicom
      smartmontools

      ffmpeg
      imagemagick
    ]
    ++ [codegpt];
}
