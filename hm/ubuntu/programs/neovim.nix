{ pkgs-unstable, ... }:
{
  programs.neovim.extraPackages = with pkgs-unstable; [
    astyle
    neocmakelsp
  ];
}
