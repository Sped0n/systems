{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./networking
    ./services
    ./system

    ./ccache.nix
    ./determinate.nix
    ./diff.nix
    ./gc.nix
    ./users.nix
  ];
}
