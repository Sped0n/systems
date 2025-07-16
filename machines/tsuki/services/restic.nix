{
  pkgs,
  home,
  ...
}: {
  services.restic-backup = {
    enable = true;
    backupDir = "${home}/infra";
    extraPath = [pkgs.docker];
    preBackupCommands = [
      "docker compose -f ${home}/infra/docker-compose.yml stop"
    ];
    postBackupCommands = [
      "docker compose -f ${home}/infra/docker-compose.yml start"
    ];
  };
}
