{ pkgs, ... }:
{
  home.packages = with pkgs; [
    popsicle
  ];
}
