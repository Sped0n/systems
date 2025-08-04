{
  home,
  username,
  ...
}: {
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  systemd.tmpfiles.rules = [
    "d ${home}/others 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
    "d ${home}/storage/gitlab-runner-cache 0755 ${username} users -"
  ];

  services.docuum = {
    enable = true;
    threshold = "60GB";
  };

  systemd.services.docuum.environment.LOG_LEVEL = "info";
}
