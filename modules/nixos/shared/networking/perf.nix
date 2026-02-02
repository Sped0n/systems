{ ... }:
{
  boot.kernel.sysctl = {
    # ECN negotiation for congestion signaling
    "net.ipv4.tcp_ecn" = 1;
    "net.ipv4.tcp_ecn_fallback" = 1;

    # TCP timestamps (RTT measurement, PAWS protection)
    "net.ipv4.tcp_timestamps" = 1;

    # window scaling for high-bandwidth/latency paths
    "net.ipv4.tcp_window_scaling" = 1;

    # socket buffer limits (throughput tuning)
    "net.core.wmem_max" = 33554432;
    "net.core.rmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 87380 33554432";

    # queue discipline and congestion control
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # connection setup and loss recovery behavior
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.mptcp.enabled" = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
  };
}
