{ pkgs, vars, ... }:
{
  services.my-restic = {
    enable = false;
    paths = [ "${vars.home}/infra" ];
    exclude = [
      "*.log"
    ];
    pruneOpts = [
      "--keep-daily 2"
    ];
    backupPrepareCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${vars.home}/infra/docker-compose.yml stop
    '';
    backupCleanupCommand = ''
      ${pkgs.docker}/bin/docker compose -f ${vars.home}/infra/docker-compose.yml start
    '';
  };
}
