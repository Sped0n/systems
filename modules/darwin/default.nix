{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./brew
    ./services
    ./system

    ./ccache.nix
    ./diff.nix
    ./gc.nix
  ];
}
