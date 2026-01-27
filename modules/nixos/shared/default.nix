{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./networking
    ./services
    ./system

    ./diff.nix
    ./gc.nix
    ./users.nix
  ];
}
