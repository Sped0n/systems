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
        docker-compose
        rclone
      ]
      ++
      # Others
      [
        codegpt
        hugo
        go
      ];
  }
