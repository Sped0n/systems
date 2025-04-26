{...}: {
  systemd.tmpfiles.rules = [
    "d /srv/eyes 0755 root root -"
  ];

  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://:10001".extraConfig = ''
        root * /srv/eyes
        file_server
        encode gzip zstd
        handle_errors {
          rewrite * /404.html
          file_server
        }
      '';

      "http://:10003".extraConfig = ''
        redir / /tennousei/index.html 301
        redir /tennousei /tennousei/index.html 301
        redir /tsuki /tsuki/index.html 301

        handle_path /tennousei/* {
          reverse_proxy http://localhost:8384 {
            header_up Host {upstream_hostport}
          }
        }
        handle_path /tsuki/* {
          reverse_proxy http://100.122.137.55:8384 {
            header_up Host {upstream_hostport}
          }
        }
        handle {
          respond 404
        }
      '';
    };
  };
}
