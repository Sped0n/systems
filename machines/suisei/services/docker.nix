{...}: {
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  services.docuum = {
    enable = true;
    threshold = "40GB";
  };

  systemd.services.docuum.environment.LOG_LEVEL = "info";
}
