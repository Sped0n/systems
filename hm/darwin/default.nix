{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/shared")

    ./packages.nix
    ./programs
  ];
}
