{
  home,
  username,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"
    "d ${home}/infra/apps 0755 ${username} users -"
  ];

  boot.kernel.sysctl = {
    "vm.overcommit_memory" = 1;
  };
}
