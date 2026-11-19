{ pkgs-unstable, ... }:
{
  programs.neovim.extraPackages = with pkgs-unstable; [
    neocmakelsp

    vtsls
    eslint
  ];
}
