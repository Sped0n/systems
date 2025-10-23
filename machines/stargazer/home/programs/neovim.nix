{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    # rust
    rust-analyzer

    # c/cpp
    clang-tools
    neocmakelsp

    # zig
    zls_0_15
  ];
}
