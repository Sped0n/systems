{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/shared")

    ./brew
    ./system

    ./diff.nix
    ./gc.nix
    ./nix.nix
  ];
}
