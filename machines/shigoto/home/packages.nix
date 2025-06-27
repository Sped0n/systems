{
  pkgs,
  pkgs-unstable,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  home.packages = with pkgs-unstable;
    [
      android-tools
      imhex
      beekeeper-studio
      popsicle

      teams-for-linux

      obsidian
    ]
    ++ [codegpt];
}
