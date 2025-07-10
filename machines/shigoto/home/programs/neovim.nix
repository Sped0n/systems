{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    # rust
    rustup

    # c/cpp
    clang-tools
    neocmakelsp

    # zig
    zls
  ];
}
