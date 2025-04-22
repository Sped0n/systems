{agenix-darwin, ...}: {
  imports = [
    agenix-darwin.homeManagerModules.default

    ./programs
    ./packages.nix
    ./secrets.nix
  ];
}
