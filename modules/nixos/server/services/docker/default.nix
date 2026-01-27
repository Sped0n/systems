{
  config,
  lib,
  vars,
  ...
}:
let
  my-docker = config.services.my-docker;
in
{
  imports = [
    ./diun.nix
    ./networking.nix
    ./telegraf.nix
  ];

  config = lib.mkIf my-docker.enable {
    boot.kernel.sysctl = {
      "vm.overcommit_memory" = 1;
    };

    systemd.tmpfiles.rules = with vars; [
      "d ${home}/infra 0755 ${username} users -"
      "d ${home}/infra/data 0755 ${username} users -"
      "d ${home}/infra/apps 0755 ${username} users -"
    ];
  };
}
