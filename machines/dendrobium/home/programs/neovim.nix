{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    # rust
    rust-analyzer

    # c/cpp
    clang-tools
    neocmakelsp

    # typescript
    vtsls
    eslint
    pnpm

    # zig
    zls_0_15
  ];
}
