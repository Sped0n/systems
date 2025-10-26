{ vars, ... }:
{
  services.logrotate.settings."${vars.home}/infra/data/vaultwarden/vaultwarden.log" = {
    copytruncate = true;
    frequency = "daily";
    size = "10M";
    rotate = 3;
    missingok = true;
    notifempty = true;
  };
}
