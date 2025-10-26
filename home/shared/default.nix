{ ... }:
{
  imports = [
    ./programs

    ./agenix.nix
    ./packages.nix
  ];

  xdg.enable = true;
}
