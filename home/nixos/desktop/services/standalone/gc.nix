{
  config,
  functions,
  lib,
  ...
}:
let
  standalone = config.services.standalone;
in
{
  disabledModules = [
    (lib.mkIf standalone.enable (functions.fromRoot "/home/shared/gc.nix"))
  ];

  config = lib.mkIf standalone.enable {
    nix.gc = {
      automatic = true;
      dates = lib.mkForce "weekly";
      options = lib.mkForce "--delete-older-than 21d";
    };
  };
}
