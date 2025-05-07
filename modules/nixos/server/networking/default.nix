{...}: {
  imports = [./sshd.nix];

  networking.firewall = {
    enable = true;
    pingLimit = "--limit 10/minute --limit-burst 5";
    trustedInterfaces = ["tailscale0"];
  };

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  services = {
    tailscale = {
      enable = true;
      interfaceName = "tailscale0";
      openFirewall = true;
    };
    fail2ban.enable = true;
  };
}
