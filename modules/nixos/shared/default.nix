{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/shared")

    ./networking

    ./diff.nix
    ./docker.nix
    ./gc.nix
    ./system.nix
    ./users.nix
  ];
}
