{ vars, ... }:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/others 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.my-docker = {
    enable = true;
    docuumThreshold = "60GB";
  };
}
