{ ... }:
{
  imports = [
    ./programs

    ./age.nix
    ./packages.nix
  ];

  xdg.enable = true;
}
