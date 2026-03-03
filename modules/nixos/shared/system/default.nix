{ ... }:
{
  imports = [
    ./grub.nix
    ./misc.nix
    ./power.nix
    ./security.nix
    ./swap.nix
    ./terminfo.nix
  ];

  system.stateVersion = "24.11";
}
