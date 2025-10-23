{
  home,
  username,
  ...
}:
{
  # systemd.tmpfiles.rules = [
  #   "d ${home}/storage 0755 ${username} users -"
  #   "d ${home}/storage/syncthing 0755 ${username} users -"
  # ];
  #
  # networking.firewall = {
  #   allowedTCPPorts = [ 22000 ];
  #   allowedUDPPorts = [
  #     22000
  #     21027
  #   ];
  # };
  #
  # services.docuum = {
  #   enable = true;
  #   threshold = "2GB";
  # };
  #
  # systemd.services.docuum.environment.LOG_LEVEL = "info";
}
