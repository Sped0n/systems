{ vars, ... }:
{
  systemd.tmpfiles.rules = with vars; [
    "d ${home}/storage/qb 0755 ${username} users -"
  ];
}
