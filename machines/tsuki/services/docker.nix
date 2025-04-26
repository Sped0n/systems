{
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"

    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/syncthing 0755 ${username} users -"
  ];

  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  };
}
