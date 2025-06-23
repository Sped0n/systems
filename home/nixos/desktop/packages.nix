{
  pkgs,
  pkgs-unstable,
  ...
}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  imports = [
    ../../shared/packages.nix
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
          # rust
          rustup

          # c/cpp
          clang-tools
          neocmakelsp
        ]
    )
    ++ [
      codegpt
    ];
}
