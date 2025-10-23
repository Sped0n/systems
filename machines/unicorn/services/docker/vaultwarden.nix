{ home, ... }:
{
  services.logrotate.settings."${home}/infra/data/vaultwarden/vaultwarden.log" = {
    copytruncate = true;
    frequency = "daily";
    size = "10M";
    rotate = 3;
    missingok = true;
    notifempty = true;
  };
}
