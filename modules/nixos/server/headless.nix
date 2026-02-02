{ ... }:
{
  # most of below config comes from
  # https://github.com/nix-community/srvos/blob/main/nixos/server/default.nix

  environment.variables.BROWSER = "echo";
  fonts.fontconfig.enable = false;

  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.menus.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;

  systemd = {
    enableEmergencyMode = false;
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';
  };
}
