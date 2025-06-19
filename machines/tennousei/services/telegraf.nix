{home, ...}: {
  services.telegraf = {
    extraConfig = {
      inputs = {
        tail = [
          {
            name_override = "traefik_access_log";
            files = ["/var/log/telegraf-binds/traefik-access.log"];
            watch_method = "inotify";
            data_format = "json";
            json_string_fields = [
              "RouterName"
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
      };

      outputs = {
        loki = [
          {
            domain = "http://tsuki:9428";
            endpoint = "/insert/loki/api/v1/push";
            gzip_request = true;
            sanitize_label_names = true;
            namepass = ["traefik_access_log"];
          }
        ];
      };
    };
  };

  users.users.telegraf.extraGroups = ["docker"];
  systemd = {
    tmpfiles.rules = [
      "d /var/log/telegraf-binds 0755 root root -"
    ];
    mounts = [
      {
        what = "${home}/infra/data/traefik/access.log";
        where = "/var/log/telegraf-binds/traefik-access.log";
        type = "none";
        options = "bind,ro"; # 'bind' creates the mirror, 'ro' makes it read-only
        wantedBy = ["multi-user.target"];
      }
    ];
    services.telegraf.after = ["tailscaled.service"];
  };
}
