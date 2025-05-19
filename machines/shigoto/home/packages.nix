{pkgs, ...}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in
  with pkgs; {
    imports = [
      ../../../home/shared/packages.nix
    ];

    home.packages =
      # Main
      [
        vim
      ]
      ++
      # Desktop Application
      [
        brave
        bitwarden-desktop
        open-vm-tools
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
