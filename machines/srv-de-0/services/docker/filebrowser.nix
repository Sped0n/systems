{ vars, ... }:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/sharing 0755 ${username} users -"
  ];
}
