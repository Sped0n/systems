{...}: {
  systemd.tmpfiles.rules = [
    "d /srv/eyes 0755 root root -"
  ];

  services.caddy = {
    enable = true;
    virtualHosts."http://:10001" = {
      extraConfig = ''
        root * /srv/eyes
        file_server
        encode gzip zstd
        handle_errors {
          rewrite * /404.html
          file_server
        }
      '';
    };
  };
}
