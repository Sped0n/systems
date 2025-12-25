{ ... }:
{
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";

    "net.core.wmem_max" = 33554432;
    "net.core.rmem_max" = 33554432;
  };
}
