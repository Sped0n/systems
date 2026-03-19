{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng
    ])
    ++ (with pkgs-unstable; [
      popsicle
      solaar
    ]);
}
