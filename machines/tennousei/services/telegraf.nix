{...}: {
  services.telegraf = {
    extraConfig = {
      inputs = {
        tail = [
          {
            name_override = "traefik_access_log";
            files = ["/var/log/traefik/access.log"];
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
  systemd.services.telegraf.after = ["tailscaled.service"];
}
