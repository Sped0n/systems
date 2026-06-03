{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/darwin")

    ./brew
    ./hm
    ./services

    ./networking.nix
  ];
}
