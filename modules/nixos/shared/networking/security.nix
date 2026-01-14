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
    daemonSettings.Definition.dbpurgeage = "60d";
    ignoreIP = [
      # warp
      "100.96.0.0/12"
    ];
  };
}
