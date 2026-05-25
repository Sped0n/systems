{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [ hunk ])
    ++ (with pkgs-unstable; [
      nixos-anywhere
    ]);
}
