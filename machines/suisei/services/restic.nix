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
    extraPath = [pkgs.docker];
    preBackupCommands = [
      "docker compose -f ${home}/infra/docker-compose.yml stop"
    ];
    postBackupCommands = [
      "docker compose -f ${home}/infra/docker-compose.yml start"
    ];
  };
}
