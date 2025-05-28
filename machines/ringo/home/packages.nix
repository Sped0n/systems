{
  pkgs,
  pkgs-unstable,
  agenix-darwin,
  ...
}: {
  imports = [
    ../../../home/darwin/packages.nix
  ];

  home.packages =
    (
      # Core
      with pkgs; [
        agenix-darwin.packages."${pkgs.system}".default
        docker
        gcc
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
        # python
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

        # bash
        bash-language-server
        shellcheck
        shfmt
      ]
    )
    ++ (
      # Others
      with pkgs; [
        ffmpeg
        imagemagick
        restic
      ]
    );
}
