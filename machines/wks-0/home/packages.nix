{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      chip-host-tools
    ])
    ++ (with pkgs-unstable; [
      nixos-anywhere
    ]);
}
