{
  config,
  determinate,
  lib,
  pkgs,
  ...
}:
{
  nix.gc = {
    interval = lib.mkDefault [
      {
        Day = 1;
        Hour = 0;
        Minute = 0;
      }
    ];
    options = lib.mkDefault "--delete-older-than 30d";
  };

  launchd.daemons."custom.nix-gc.system" = {
    script = ''exec ${
      determinate.inputs.nix.packages."${pkgs.stdenv.system}".default
    }/bin/nix-collect-garbage ${config.nix.gc.options}'';
    serviceConfig = {
      StartCalendarInterval = config.nix.gc.interval;
      RunAtLoad = false;
    };
  };
}
