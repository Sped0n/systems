{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./brew
    ./system

    ./ccache.nix
    ./determinate.nix
    ./diff.nix
    ./gc.nix
  ];
}
