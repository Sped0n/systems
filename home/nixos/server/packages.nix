{pkgs, ...}:
with pkgs; {
  imports = [
    ../../shared/packages.nix
  ];
  home.packages =
    # Utils
    [
      nali
    ]
    ++
    # Others
    [
      restic
      beszel
    ];
}
