{ libutils, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/shared")

    ./networking
    ./services
  ];
}
