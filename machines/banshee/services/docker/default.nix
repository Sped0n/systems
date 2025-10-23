{
  home,
  username,
  ...
}:
{
  imports = [
    ./traefik.nix
  ];

  systemd.tmpfiles.rules = [
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.docuum.threshold = "20GB";
}
