{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./networking
    ./services
    ./system

    ./determinate.nix
    ./diff.nix
    ./gc.nix
    ./users.nix
  ];
}
