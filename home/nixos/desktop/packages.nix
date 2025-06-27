{pkgs-unstable, ...}: {
  imports = [
    ../../shared/packages.nix
  ];

  home.packages = with pkgs-unstable; [
    brave
    bitwarden-desktop
    peazip
  ];
}
