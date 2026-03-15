{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixos-rebuild-ng
    chip-host-tools

    popsicle
  ];
}
