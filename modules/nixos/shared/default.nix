{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./networking
    ./system

    ./diff.nix
    ./docker.nix
    ./gc.nix
    ./users.nix
  ];
}
