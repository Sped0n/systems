{ pkgs, vars, ... }:
{
  services.my-restic = {
    enable = true;
    paths = [ "${vars.home}/infra" ];
    exclude = [
      "*.log"
    ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 3"
    ];
    backupPrepareCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${vars.home}/infra/docker-compose.yml stop
    '';
    backupCleanupCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${vars.home}/infra/docker-compose.yml start
    '';
  };
}
