{pkgs, ...}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in
  with pkgs; {
    imports = [
      ../../../home/nixos/server/packages.nix
    ];

    home.packages =
      # Main
      [
        vim
      ]
      ++
      # Languages supports
      [
        # python
        uv
        ruff
        basedpyright

        # rust
        rustup

        # c/cpp
        clang-tools
        neocmakelsp
      ]
      ++
      # Others
      [
        codegpt
      ];
  }
