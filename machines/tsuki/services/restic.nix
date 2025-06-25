{
  pkgs,
  home,
  ...
}: {
  services.restic-backup = {
    enable = true;
    backupDir = "${home}/infra";
    preBackupCommands = [
      "${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml stop"
    ];
    postBackupCommands = [
      "${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml start"
    ];
  };
}
