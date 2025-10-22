{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  cfg = config.services.my-tailscale;
in
{
  options.services.my-tailscale = {
    enable = lib.mkEnableOption "Enable tailscale";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      extraCommands = ''
        iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      '';
      extraStopCommands = ''
        iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE
      '';
      trustedInterfaces = [ "tailscale0" ];
    };

    services.tailscale = {
      enable = true;
      package = pkgs-unstable.tailscale;
      interfaceName = "tailscale0";
      openFirewall = true;
    };
  };
}
