{ ... }:
{
  networking.firewall = {
    enable = true;
    pingLimit = "--limit 10/minute --limit-burst 5";
    checkReversePath = false;
  };
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    bantime-increment.enable = true;
  };

  # BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
