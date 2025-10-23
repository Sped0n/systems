{ home, username, ... }:
{
  systemd.tmpfiles.rules = [
    "d ${home}/storage/qb 0755 ${username} users -"
  ];
}
