{ config, lib, ... }:
let
  standalone = config.services.standalone;
in
{
  config = lib.mkIf standalone.enable {
    targets.genericLinux = {
      enable = true;
      gpu.enable = true;
    };
  };
}
