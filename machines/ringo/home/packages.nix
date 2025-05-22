{
  pkgs,
  agenix-darwin,
  ...
}:
with pkgs; {
  imports = [
    ../../../home/darwin/packages.nix
  ];

  home.packages =
    # Core
    [
      agenix-darwin.packages."${pkgs.system}".default
      docker
      gcc
    ]
    ++
    # Utils
    [
      bfg-repo-cleaner
      hyperfine
      act
      ast-grep
      minicom
      nali
      tokei
      smartmontools
    ]
    ++
    # Languages supports
    [
      # python
      uv
      ruff
      basedpyright

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
    ++
    # Others
    [
      ffmpeg
      imagemagick
      restic
    ];
}
