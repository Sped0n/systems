{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/home/shared")

    ./packages.nix
    ./programs
  ];
}
