{
  home,
  username,
  ...
}:
{
  imports = [
    ./traefik.nix
    ./syncthing.nix
    ./vaultwarden.nix
    ./qb.nix
  ];

  systemd.tmpfiles.rules = [
    "d ${home}/sharing 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.docuum.threshold = "25GB";
}
