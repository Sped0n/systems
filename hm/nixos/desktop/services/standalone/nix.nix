{
  config,
  functions,
  lib,
  secrets,
  vars,
  ...
}:
let
  standalone = config.services.standalone;
in
{
  config = lib.mkIf standalone.enable (
    lib.recursiveUpdate
      (import (functions.fromRoot "/modules/shared/nix/settings.nix") { inherit vars; })
      {
        age.secrets."nix-gh-rate-limit-bypass" = {
          mode = "0400";
          file = "${secrets}/ages/nix-gh-rate-limit-bypass.age";
          path = "${vars.home}/.config/nix/nix-gh-rate-limit-bypass.conf";
        };

        nix.extraOptions = ''
          !include nix-gh-rate-limit-bypass.conf
        '';
      }
  );
}
