{ config, ... }:
{
  determinateNix = {
    enable = true;
    customSettings = config.nix.settings // {
      builders-use-substitutes = true;
    };
    determinateNixd.garbageCollector.strategy = "disabled";
  };
}
