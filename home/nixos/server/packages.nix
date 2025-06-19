{
  pkgs,
  pkgs-unstable,
  ...
}: {
  imports = [
    ../../shared/packages.nix
  ];
  home.packages =
    # Utils
    (with pkgs-unstable; [
      nali
    ])
    ++ (with pkgs; [
      restic
    ]);
}
