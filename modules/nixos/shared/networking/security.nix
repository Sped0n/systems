{ ... }:
{
  networking.firewall = {
    enable = true;
    pingLimit = "--limit 10/minute --limit-burst 5";
    checkReversePath = false;
  };

  services.fail2ban = {
    enable = true;
    bantime = "12h";
    bantime-increment = {
      enable = true;
      rndtime = "30m";
    };
    ignoreIP = [
      # tailscale
      "100.64.0.0/10"
      "fd7a:115c:a1e0::/48"
    ];
  };
}
