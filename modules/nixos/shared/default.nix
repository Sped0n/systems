{
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./networking.nix
    ./virt.nix
  ];

  nix.gc.dates = "weekly";
}
