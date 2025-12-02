{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/darwin")

    ./brew
    ./home

    ./age.nix
    ./networking.nix
    ./nix.nix
  ];
}
