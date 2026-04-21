{ pkgs, pkgs-unstable, ... }:
{
  programs.neovim.extraPackages =
    (with pkgs; [ lldb ])
    ++ (with pkgs-unstable; [
      clang-tools
      neocmakelsp

      rust-analyzer

      zls_0_15

      vtsls
      eslint

      gopls
      delve
      gofumpt
    ]);
}
