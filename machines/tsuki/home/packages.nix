{pkgs, ...}: let
  codegpt = pkgs.callPackage ../../../pkgs/codegpt.nix {};
in {
  imports = [
    ../../../home/nixos/server/packages.nix
  ];

  home.packages =
    # Others
    [
      codegpt
    ];
}
