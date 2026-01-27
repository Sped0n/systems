{ vars, ... }:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.my-docker = {
    enable = true;
    docuumThreshold = "20GB";
  };
}
