{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixos-rebuild-ng

    popsicle
  ];
}
