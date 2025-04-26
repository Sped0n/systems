{
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./secrets.nix

    ./networking
    ./services
  ];

  nix.gc.dates = "weekly";
}
