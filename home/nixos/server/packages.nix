{pkgs, ...}: {
  imports = [
    ../../shared/packages.nix
  ];

  home.packages = with pkgs; [
    docker-compose
  ];
}
