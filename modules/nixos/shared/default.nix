{
  imports = [
    ../../shared

    ./system.nix
    ./users.nix
    ./networking.nix
    ./virt.nix
  ];

  nix.gc.dates = "weekly";

  # NOTE: for codeium language server
  programs.nix-ld.enable = true;
}
