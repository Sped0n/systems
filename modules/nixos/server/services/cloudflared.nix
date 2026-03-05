{
  config,
  lib,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
let
  cfg = config.services.my-cloudflared;
  hostname = config.networking.hostName;
in
{
  options.services.my-cloudflared = {
    enable = lib.mkEnableOption "Enable Cloudflare Tunnel";
  };

  config = lib.mkIf cfg.enable {
    age.secrets."${hostname}-cf-tunnel-json" = {
      file = "${secrets}/ages/${hostname}-cf-tunnel-json.age";
      owner = "root";
      mode = "0400";
    };

    # https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/
    networking.firewall = {
      allowedTCPPorts = [ 7844 ];
      allowedUDPPorts = [ 7844 ];
    };

    services.cloudflared = {
      enable = true;
      package = pkgs-unstable.cloudflared;
      tunnels = {
        "${vars.${hostname}.cfTunnelId}" = {
          default = "http_status:404";
          credentialsFile = config.age.secrets."${hostname}-cf-tunnel-json".path;
        };
      };
    };
  };
}
