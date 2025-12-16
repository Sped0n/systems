{
  config,
  determinate,
  lib,
  pkgs,
  ...
}:
let
  gcCommand = ''exec ${
    determinate.inputs.nix.packages."${pkgs.stdenv.system}".default
  }/bin/nix-collect-garbage ${config.nix.gc.options}'';
in
{
  nix.gc = {
    interval = lib.mkDefault [
      {
        Day = 1;
        Hour = 3;
        Minute = 0;
      }
    ];
    options = lib.mkDefault "--delete-older-than 30d";
  };

  launchd = {
    daemons."custom.nix-gc.system" = {
      script = gcCommand;
      serviceConfig = {
        StartCalendarInterval = config.nix.gc.interval;
        RunAtLoad = false;
      };
    };

    agents."custom.nix-gc.user" = {
      script = gcCommand;
      path = [ determinate.inputs.nix.packages."${pkgs.stdenv.system}".default ];
      serviceConfig = {
        StartCalendarInterval = config.nix.gc.interval;
        RunAtLoad = false;
      };
    };
  };
}
