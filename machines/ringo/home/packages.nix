{
  pkgs,
  pkgs-unstable,
  agenix-darwin,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  imports = [
    ../../../home/darwin/packages.nix
  ];

  home.packages =
    (
      # Core
      with pkgs; [
        agenix-darwin.packages."${pkgs.system}".default
        docker
      ]
    )
    ++ (
      # Utils
      (with pkgs; [
        bfg-repo-cleaner
        minicom
        smartmontools
      ])
      ++ (with pkgs-unstable; [
        act
        hyperfine
        ast-grep
        nali
        tokei
      ])
    )
    ++ (
      # Languages supports
      with pkgs-unstable; [
        # go
        gopls
        gofumpt

        # rust
        rustup

        # c/cpp
        clang-tools
        neocmakelsp

        # typescript
        vtsls
        eslint
        pnpm

        # zig
        zls
      ]
    )
    ++ (
      # Others
      with pkgs; [
        ffmpeg
        imagemagick
      ]
    )
    ++ [codegpt];
}
