{...}: {
  imports = [./sshd.nix];

  networking.firewall = {
    enable = true;
    pingLimit = "--limit 10/minute --limit-burst 5";
    trustedInterfaces = ["tailscale0"];
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
