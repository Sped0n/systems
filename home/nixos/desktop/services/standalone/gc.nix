{
  config,
  lib,
  ...
}:
let
  standalone = config.services.standalone;
in
{
  config = lib.mkIf standalone.enable {
    nix.gc = {
      automatic = true;
      dates = lib.mkForce "weekly";
      options = lib.mkForce "--delete-older-than 21d";
    };
  };
}
