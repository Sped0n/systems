{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];
}
