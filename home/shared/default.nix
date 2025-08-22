{ ... }:
{
  imports = [
    ./packages.nix
    ./programs

    ./agenix.nix
  ];

  xdg.enable = true;
}
