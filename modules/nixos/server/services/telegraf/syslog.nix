{ config, lib, ... }:
let
  cfg = config.services.my-telegraf;
in
{
  config = lib.mkIf cfg.enable {
    services = {
      journald.forwardToSyslog = true;
      syslog-ng = {
        enable = true;
        extraConfig = ''
          source s_src {
            system();
          };

          destination d_telegraf {
            syslog("127.0.0.1" port(6514));
          };

          filter f_skip_docker_containers {
            not program("docker#*");
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
                (level(notice) or level(warning) or level(err)) and
                message("veth")
              );
          };

          filter f_ignore_restic {
              not (
                program("restic") and
                level(info)
              );
          };

          filter f_basic {
              (
                  (program("tailscaled") or program("dhcpcd")) and
                  level(notice..emerg)
              )
              or
              (
                  not (program("tailscaled") or program("dhcpcd")) and
                  level(info..emerg)
              )
          };

          log {
            source(s_src);
            filter(f_skip_docker_containers);
            filter(f_ignore_firewall);
            filter(f_ignore_kernel_veth);
            filter(f_ignore_dhcpcd_veth);
            filter(f_ignore_restic);
            filter(f_basic);
            destination(d_telegraf);
          };
        '';
      };
    };

    systemd.services.syslog-ng.after = [ "telegraf.service" ];
  };
}
