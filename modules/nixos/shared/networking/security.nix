{ ... }:
{
  boot.kernel.sysctl = {
    # TIME-WAIT assassination protection
    "net.ipv4.tcp_rfc1337" = 1;

    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_max_syn_backlog" = 16384;
    "net.ipv4.tcp_synack_retries" = 3;
    "net.core.somaxconn" = 8192;

    # ICMP restrictions
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  };

  networking.firewall = {
    enable = true;
    pingLimit = "--limit 10/minute --limit-burst 5";
    checkReversePath = "loose";
  };

  services.fail2ban = {
    enable = true;
    bantime = "12h";
    bantime-increment = {
      enable = true;
      rndtime = "30m";
    };
    daemonSettings.Definition.dbpurgeage = "60d";
    ignoreIP = [
      # mesh
      "100.96.0.0/16"
    ];
  };
}
