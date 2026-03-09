{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/darwin")

    ./brew
    ./home

    ./determinate.nix
    ./networking.nix
  ];
}
