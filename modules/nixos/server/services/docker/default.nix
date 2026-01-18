{ vars, ... }:
{
  imports = [
    ./diun.nix
    ./docuum.nix
    ./networking.nix
  ];

  boot.kernel.sysctl = {
    "vm.overcommit_memory" = 1;
  };

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"
    "d ${home}/infra/apps 0755 ${username} users -"
  ];
}
