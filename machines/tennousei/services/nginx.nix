{...}: {
  systemd.tmpfiles.rules = [
    "d /srv/eyes 0755 root root -"
  ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    virtualHosts = {
      "eyes" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 10001;
          }
          {
            addr = "[::]";
            port = 10001;
          }
        ];
        root = "/srv/eyes";
        extraConfig = ''
          error_page 404 /404.html;
        '';
      };
    };
  };
}
