{ functions, lib, ... }:
{
  disabledModules = [
    (functions.fromRoot "/home/shared/gc.nix")
  ];

  nix.gc = {
    automatic = true;
    dates = lib.mkForce "weekly";
    options = lib.mkForce "--delete-older-than 21d";
  };
}
