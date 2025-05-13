{agenix, ...}: {
  imports = [
    agenix.homeManagerModules.default

    ./programs
    ./packages.nix
    ./secrets.nix
  ];
}
