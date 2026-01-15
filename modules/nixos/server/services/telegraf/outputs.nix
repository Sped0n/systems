{
  config,
  lib,
  vars,
  ...
}:
let
  cfg = config.services.my-telegraf;
in
{
  config = lib.mkIf cfg.enable {
    services.telegraf.extraConfig.outputs = {
      influxdb = {
        urls = [ "http://100.96.0.${vars."srv-de-0".meshId}:8428" ];
        database = "victoriametrics";
        skip_database_creation = true;
        exclude_retention_policy_tag = true;
        content_encoding = "gzip";
        namepass = [
          "system*"
          "kernel*"
          "cpu*"
          "mem*"
          "swap*"
          "disk*"
          "diskio*"
          "net*"
          "netstat*"
          "docker*"
          "processes*"
        ];
      };

      loki = [
        {
          domain = "http://100.96.0.${vars."srv-de-0".meshId}:9428";
          endpoint = "/insert/loki/api/v1/push";
          gzip_request = true;
          sanitize_label_names = true;
          namepass = [
            "info*"
            "syslog*"
          ];
        }
      ];
    };
  };
}
