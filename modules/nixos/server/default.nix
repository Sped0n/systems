{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/nixos/shared")

    ./services
    ./system

    ./mesh.nix
  ];
}
