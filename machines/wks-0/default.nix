{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/darwin")

    ./brew
    ./hm

    ./determinate.nix
    ./networking.nix
  ];
}
