{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/modules/darwin")

    ./brew
    ./home

    ./age.nix
    ./determinate.nix
    ./networking.nix
  ];
}
