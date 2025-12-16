{ ... }:
{
  imports = [
    ./programs

    ./age.nix
    ./gc.nix
    ./packages.nix
  ];

  xdg.enable = true;
}
