{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    # rust
    rust-analyzer

    # c/cpp
    astyle
    clang-tools
    neocmakelsp

    # zig
    zls_0_15

    # javascript
    vtsls
  ];
}
