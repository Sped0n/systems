{
  pkgs,
  pkgs-unstable,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  imports = [
    ../../../home/shared/packages.nix
  ];

  home.packages =
    (
      # Desktop Application
      with pkgs-unstable;
        [
          brave
          bitwarden-desktop
          jan
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
    )
    ++
    # Others
    [
      codegpt
    ];
}
