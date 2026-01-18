{ lib, ... }:
{
  services.docuum = {
    enable = true;
    threshold = lib.mkDefault "10GB";
  };
  systemd.services.docuum.environment.LOG_LEVEL = "info";
}
