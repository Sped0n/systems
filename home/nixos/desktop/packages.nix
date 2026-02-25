{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    bitwarden-desktop
    peazip
  ];
}
