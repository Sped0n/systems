{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/shared")

    ./brew
    ./system

    ./diff.nix
    ./gc.nix
    ./networking.nix
    ./nix.nix
  ];
}
