{
  pkgs,
  home,
  ...
}: {
  services.restic-backup = {
    enable = true;
    backupDir = "${home}/infra";
    keepDaily = 2;
    keepWeekly = 0;
    preBackupCommands = [
      "${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml stop"
    ];
    postBackupCommands = [
      "${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml start"
    ];
  };
}
