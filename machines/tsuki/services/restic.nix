{
  home,
  pkgs,
  ...
}: {
  _services.restic.enable = true;

  services.restic.backups."main" = {
    paths = ["${home}/infra"];
    exclude = [
      "*.log"
    ];
    pruneOpts = [
      "--keep-daily 3"
      "--keep-weekly 2"
    ];
    backupPrepareCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml stop
    '';
    backupCleanupCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${home}/infra/docker-compose.yml start
    '';
  };
}
