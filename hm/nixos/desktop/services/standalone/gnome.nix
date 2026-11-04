{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.services.standalone.enable {
    home.packages = [ pkgs.gnome-screenshot ];
  };
}
