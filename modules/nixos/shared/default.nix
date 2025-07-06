{lib, ...}: {
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./networking.nix
    ./docker.nix
  ];

  nix.gc.dates = lib.mkDefault "daily";
}
