{ ... }:
{
  imports = [
    ./grub.nix
    ./kernel.nix
    ./misc.nix
    ./security.nix
    ./swap.nix
    ./terminfo.nix
  ];

  system.stateVersion = "24.11";
}
