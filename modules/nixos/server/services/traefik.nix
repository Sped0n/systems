{
  lib,
  config,
  functions,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  my-traefik = config.services.my-traefik;
  my-telegraf = config.services.my-telegraf;

  toml = pkgs.formats.toml { };
  traefikOtelPort = 4327;
in
{
  options.services.my-traefik = {
    enable = lib.mkEnableOption "Whether to enable the custom Traefik module.";

    dynamicConfigOptions = lib.mkOption {
      description = ''
        Dynamic configuration for Traefik.
      '';
      type = toml.type;
      default = { };
    };
  };

  config = lib.mkIf my-traefik.enable {
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
          api.dashboard = true;

          experimental.plugins."traefik-real-ip" = {
            moduleName = "github.com/jramsgz/traefik-real-ip";
            version = "v1.0.7";
          };

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
              headers.names = {
                "Content-Type" = "keep";
                "Referer" = "keep";
                "User-Agent" = "keep";
                "Cf-Connecting-Ip" = "keep";
                "Cf-Ipcountry" = "keep";
                "Cf-Ray" = "keep";
              };
            };
          };
          metrics.otlp = lib.mkIf my-telegraf.enable {
            addEntryPointsLabels = false;
            addRoutersLabels = false;
            addServicesLabels = true;
            pushInterval = "10s";
            explicitBoundaries = [
              0.002
              0.005
              0.01
              0.02
              0.05
              0.1
              0.2
              0.5
              1
              2
            ];
            grpc = {
              endpoint = "localhost:${toString traefikOtelPort}";
              insecure = true;
            };
          };

          entryPoints.https = {
            address = ":4443";
            http.tls.domains = [
              {
                main = "\${DNS_DOMAIN}";
                sans = [
                  "*.\${DNS_DOMAIN}"
                ];
              }
            ];
            transport.respondingTimeouts = {
              readTimeout = "600s";
              writeTimeout = "600s";
            };
          };

          providers.docker = {
            endpoint = "unix:///var/run/docker.sock";
            exposedByDefault = false;
          };
        };
        dynamicConfigOptions = functions.mergeToml {
          http.middlewares.cftunnel.plugin.traefik-real-ip.excludednets = [ ];
        } my-traefik.dynamicConfigOptions;
      };

      logrotate.settings."/var/log/traefik/access.log" = {
        copytruncate = true;
        frequency = "hourly";
        size = "100K";
        rotate = 0;
        missingok = true;
        notifempty = true;
      };

      my-telegraf.extraConfig = lib.mkIf my-telegraf.enable {
        inputs = {
          opentelemetry = [
            {
              service_address = "localhost:${toString traefikOtelPort}";
              namedrop = [ "traefik_config*" ];
              fieldexclude = [ "start_time_unix_nano" ];
              tagexclude = [
                "host.name"
                "os.*"
                "process.*"
                "scope.*"
                "telemetry.*"
                "otel.*"
              ];
            }
          ];
          tail = [
            {
              name_override = "traefik_access_log";
              files = [ "/var/log/traefik/access.log" ];
              watch_method = "inotify";
              initial_read_offset = "saved-or-end";
              data_format = "json";
              json_string_fields = [
                "request_Cf-Ray"
                "request_Referer"
              ];
              tag_keys = [
                "DownstreamStatus"
                "downstream_Content-Type"
                "RequestHost"
                "RequestMethod"
                "RequestPath"
                "request_Cf-Connecting-Ip"
                "request_Cf-Ipcountry"
                "request_User-Agent"
                "ServiceName"
              ];
              tags = {
                log_source = "telegraf";
                metric_type = "logs";
              };
            }
          ];
        };

        outputs = {
          influxdb = [
            {
              urls = [ "http://100.96.0.${vars."srv-de-0".meshId}:8428" ];
              database = "victoriametrics";
              skip_database_creation = true;
              exclude_retention_policy_tag = true;
              content_encoding = "gzip";
              namedrop = [ "traefik_access_log" ];
              namepass = [ "traefik*" ];
            }
          ];
          loki = [
            {
              domain = "http://100.96.0.${vars."srv-de-0".meshId}:10428";
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
