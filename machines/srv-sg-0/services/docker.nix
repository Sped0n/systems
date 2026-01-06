{ vars, ... }:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.docuum.threshold = "20GB";
}
