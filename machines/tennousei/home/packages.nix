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
        cloudflared
        docker-compose
        vim
      ]
      ++
      # Others
      [
        codegpt
        hugo
        go
      ];
  }
