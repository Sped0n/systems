{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./networking
    ./services
    ./system

    ./ccache.nix
    ./diff.nix
    ./gc.nix
    ./users.nix
  ];
}
