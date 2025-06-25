{
  pkgs,
  pkgs-unstable,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  home.packages =
    (
      with pkgs;
      # Dev tools
        [
          docker
          bfg-repo-cleaner
          minicom
          smartmontools
        ]
        ++
        # Others
        [
          ffmpeg
          imagemagick
        ]
    )
    ++ (
      with pkgs-unstable;
      # Dev tools
        [
          act
          hyperfine
          ast-grep
        ]
        ++
        # CLI tools
        [
          nali
          tokei
        ]
        ++ [
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
    ++ [codegpt];
}
