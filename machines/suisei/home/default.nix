{...}: {
  imports = [
    ../../../home/nixos/server

    ./programs
    ./packages.nix
    ./secrets.nix
  ];
}
