{ ... }:
{
  imports = [
    ./programs

    ./age.nix
    ./determinate.nix
    ./gc.nix
    ./packages.nix
  ];

  xdg.enable = true;
}
