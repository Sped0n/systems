{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./brew
    ./system

    ./determinate.nix
    ./diff.nix
    ./gc.nix
  ];
}
