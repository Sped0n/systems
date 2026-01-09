{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  cfg = config.services.my-traefik;
  format = pkgs.formats.toml { };
in
{
  options.services.my-traefik = {
    enable = lib.mkEnableOption "Enable Traefik reverse proxy service.";
    dynamicConfigOptions = lib.mkOption {
      description = ''
        Dynamic configuration for Traefik.
      '';
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.traefik.extraGroups = [ "docker" ];
    systemd.tmpfiles.rules = [
      "d /var/log/traefik 0755 traefik traefik -"
      "f /var/log/traefik/access.log 0755 traefik traefik -"
    ];

    services = {
      traefik = {
        enable = true;
        package = pkgs-unstable.traefik;
        staticConfigOptions = {
          global = {
            checkNewVersion = false;
            sendAnonymousUsage = false;
          };

          experimental.plugins."traefik-real-ip" = {
            moduleName = "github.com/jramsgz/traefik-real-ip";
            version = "v1.0.4";
          };

          api.dashboard = true;

          log.level = "WARN";
          accessLog = {
            filePath = "/var/log/traefik/access.log";
            format = "json";
            fields = {
              names = {
                ClientHost = "drop";
                ClientPort = "drop";
                ClientAddr = "drop";
                ClientUsername = "drop";
                DownstreamContentSize = "drop";
                Duration = "drop";
                OriginContentSize = "drop";
                OriginStatus = "drop";
                OriginDuration = "drop";
                Overhead = "drop";
                SpanId = "drop";
                StartLocal = "drop";
                StartUTC = "drop";
                TraceId = "drop";
                GzipRatio = "drop";
                RetryAttempts = "drop";
              };
              headers = {
                names = {
                  "Content-Type" = "keep";
                  Referer = "keep";
                  "User-Agent" = "keep";
                  "Cf-Connecting-Ip" = "keep";
                  "Cf-Ipcountry" = "keep";
                  "Cf-Ray" = "keep";
                };
              };
            };
          };
          metrics.otlp = {
            addEntryPointsLabels = false;
            pushInterval = "10s";
            http.endpoint = "http://100.96.0.${vars."srv-de-0".warpId}:8428/opentelemetry/v1/metrics";
          };

          entryPoints = {
            https = {
              address = ":4443";
              http = {
                tls = {
                  domains = [
                    {
                      main = "\${DNS_DOMAIN}";
                      sans = [
                        "*.\${DNS_DOMAIN}"
                      ];
                    }
                  ];
                };
              };
              transport = {
                respondingTimeouts = {
                  readTimeout = "600s";
                  writeTimeout = "600s";
                };
              };
            };
          };

          providers = {
            docker = {
              endpoint = "unix:///var/run/docker.sock";
              exposedByDefault = false;
            };
          };
        };
        dynamicConfigOptions = lib.recursiveUpdate {
          http.middlewares.cftunnel.plugin.traefik-real-ip.excludednets = [ ];
        } cfg.dynamicConfigOptions;
      };

      logrotate.settings = {
        "/var/log/traefik/access.log" = {
          copytruncate = true;
          frequency = "hourly";
          size = "100K";
          rotate = 0;
          missingok = true;
          notifempty = true;
        };
      };

      telegraf = {
        extraConfig = {
          inputs.tail = [
            {
              name_override = "traefik_access_log";
              files = [ "/var/log/traefik/access.log" ];
              watch_method = "inotify";
              initial_read_offset = "saved-or-end";
              data_format = "json";
              json_string_fields = [
                "ServiceName"
                "downstream_Content-Type"
                "request_Cf-Ray"
                "request_Referer"
              ];
              tag_keys = [
                "DownstreamStatus"
                "RequestHost"
                "RequestMethod"
                "RequestPath"
                "request_Cf-Connecting-Ip"
                "request_Cf-Ipcountry"
                "request_User-Agent"
              ];
              tags = {
                metric_type = "logs";
                log_source = "telegraf";
              };
            }
          ];

          outputs.loki = [
            {
              domain = "http://100.96.0.${vars."srv-de-0".warpId}:9428";
              endpoint = "/insert/loki/api/v1/push";
              gzip_request = true;
              sanitize_label_names = true;
              namepass = [ "traefik_access_log" ];
            }
          ];
        };
      };
    };
  };

}
