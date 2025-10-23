{
  home,
  username,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${home}/others 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.docuum.threshold = "60GB";
}
