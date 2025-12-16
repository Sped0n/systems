{ config, lib, ... }:
let
  cfg = config.services.my-determinate;
in
{
  options.services.my-determinate = {
    enable = lib.mkEnableOption "Enable determinate JSON config writer";

    config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Configuration written to /etc/determinate/config.json.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."determinate/config.json".text = builtins.toJSON cfg.config;
  };
}
