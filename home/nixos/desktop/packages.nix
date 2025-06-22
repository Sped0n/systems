{
  pkgs,
  pkgs-unstable,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  imports = [
    ../shared/packages.nix
  ];

  home.packages =
    (
      # Desktop Application
      with pkgs-unstable;
        [
          brave
          bitwarden-desktop
        ]
        ++
        # Languages supports
        [
          # python
          ruff
          basedpyright

          # rust
          rustup

          # c/cpp
          clang-tools
          neocmakelsp

          # bash
          bash-language-server
          shellcheck
          shfmt
        ]
    )
    ++ [
      codegpt
    ];
}
