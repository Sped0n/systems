{
  config,
  lib,
  vars,
  ...
}:
let
  my-telegraf = config.services.my-telegraf;

  extraNames = builtins.attrNames my-telegraf.syslogExtraFilters;
  isValidIdent = name: builtins.match "^[A-Za-z_][A-Za-z0-9_]*$" name != null;
  renderFilter = name: body: ''
    filter f_${name} {
      ${lib.strings.trim body}
    };
  '';
in
{
  config = lib.mkIf my-telegraf.enable {
    assertions = [
      {
        assertion = lib.all isValidIdent extraNames;
        message = "services.my-telegraf.syslogExtraFilters keys must match [A-Za-z_][A-Za-z0-9_]*";
      }
    ];

    services = {
      journald.forwardToSyslog = true;

      syslog-ng = {
        enable = true;
        # mkAfter so other modules can still mkBefore/mkAfter their own fragments
        extraConfig = lib.mkAfter ''
          source s_src { system(); };

          destination d_telegraf {
            syslog("127.0.0.1" port(6514));
          };

          filter f_ignore_firewall {
            not (
              program("kernel") and 
              level(info) and 
              message("refused connection:")
            );
          };

          filter f_ignore_kernel_veth {
            not (
              program("kernel") and
              level(info) and
              message("veth")
            );
          };

          filter f_ignore_dhcpcd_veth {
            not (
              program("dhcpcd") and
              level(notice..err) and
              message("veth")
            );
          };

          filter f_ignore_dhcpcd_noise {
            not program("dhcpcd") and level(debug..info);
          };

          ${lib.concatStringsSep "\n\n" (
            map (name: renderFilter name my-telegraf.syslogExtraFilters.${name}) extraNames
          )}

          log {
            source(s_src);
            filter(f_ignore_firewall);
            filter(f_ignore_kernel_veth);
            filter(f_ignore_dhcpcd_veth);
            filter(f_ignore_dhcpcd_noise);
          ${lib.concatMapStringsSep "\n" (name: "  filter(f_${name});") extraNames}
            destination(d_telegraf);
          };
        '';
      };

      my-telegraf.extraConfig = {
        inputs.syslog = {
          server = "tcp://127.0.0.1:6514";
          tagexclude = [
            "source"
            "hostname"
          ];
          fieldexclude = [
            "version"
            "severity_code"
            "facility_code"
            "timestamp"
          ];
          tags = {
            metric_type = "logs";
            log_source = "telegraf";
          };
        };
        outputs.loki = [
          {
            domain = "http://100.96.0.${vars."srv-de-0".meshId}:9428";
            endpoint = "/insert/loki/api/v1/push";
            gzip_request = true;
            sanitize_label_names = true;
            namepass = [ "syslog" ];
          }
        ];
      };
    };

    systemd.services.syslog-ng.after = [ "telegraf.service" ];
  };
}
