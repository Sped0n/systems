{ pkgs-unstable, ... }:
{
  programs.neovim.extraPackages = with pkgs-unstable; [
    clang-tools
    neocmakelsp

    vtsls
    eslint
  ];
}
