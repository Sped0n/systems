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

    # zig
    zls_0_15

    # latex
    zathura
    bibtex-tidy
  ];
}
