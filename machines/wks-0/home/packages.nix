{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    nixos-anywhere
  ];
}
