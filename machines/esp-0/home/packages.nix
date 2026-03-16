{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng
      chip-host-tools
    ])
    ++ (with pkgs-unstable; [
      popsicle
      solaar
    ]);
}
