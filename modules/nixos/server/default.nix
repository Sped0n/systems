{
  imports = [
    ../../shared

    ./system.nix
    ./networking.nix
    ./users.nix
    ./sshd.nix
  ];

  nix.gc.dates = "weekly";
}
