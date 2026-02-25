{ vars, ... }:
{
  systemd.tmpfiles.rules = [
    "d ${vars.home}/work 0755 ${vars.username} users -"
    "d ${vars.home}/eden 0755 ${vars.username} users -"
  ];
}
