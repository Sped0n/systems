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
      "100.0.0.0/24" # tailscale
    ];
  };
}
