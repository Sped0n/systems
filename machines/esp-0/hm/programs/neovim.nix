{ pkgs-unstable, ... }:
{
  programs.neovim.extraPackages = with pkgs-unstable; [
    astyle
    clang-tools
    neocmakelsp
  ];
}
