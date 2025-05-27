{
  pkgs,
  pkgs-unstable,
  agenix,
  ...
}: {
  imports = [
    ../../../home/nixos/desktop/packages.nix
  ];

  home.packages =
    (with pkgs; [
      agenix.packages."${pkgs.system}".default

      android-tools

      popsicle
      peazip
    ])
    ++ (with pkgs-unstable; [
      beekeeper-studio
    ]);
}
