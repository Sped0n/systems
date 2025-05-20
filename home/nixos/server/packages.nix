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
    ++
    # Others
    (with pkgs-unstable; [
      beszel
    ])
    ++ (with pkgs; [
      restic
    ]);
}
