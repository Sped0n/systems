{
  config,
  lib,
  vars,
  ...
}:
let
  my-docker = config.services.my-docker;
  my-telegraf = config.services.my-telegraf;
in
{
  config = lib.mkIf (my-docker.enable && my-telegraf.enable) {
    users.users.telegraf.extraGroups = [ "docker" ];

    services.my-telegraf = {
      extraConfig = {
        inputs.docker = {
          timeout = "10s";
          source_tag = true;
          docker_label_exclude = [
            "traefik.*"
            "com.*"
            "org.*"
            "io.*"
            "build_version"
            "summary"
            "description"
            "maintainer"
          ];
        };
        outputs.influxdb = [
          {
            urls = [ "http://100.96.0.${vars."srv-de-0".meshId}:8428" ];
            database = "victoriametrics";
            skip_database_creation = true;
            exclude_retention_policy_tag = true;
            content_encoding = "gzip";
            namepass = [ "docker*" ];
          }
        ];
      };

      syslogExtraFilters.ignore_docker = ''
        not program("docker#*");
      '';
    };
  };
}
