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
  host = config.networking.hostName;
in
{
  options.services.my-cloudflared = {
    enable = lib.mkEnableOption "Enable Cloudflare Tunnel";
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
      "net.core.rmem_max" = 7500000;
      "net.core.wmem_max" = 7500000;
    };

    age.secrets."${host}-cf-tunnel-json" = {
      file = "${secrets}/ages/${host}-cf-tunnel-json.age";
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
        "${vars.${host}.cfTunnelId}" = {
          default = "http_status:404";
          credentialsFile = config.age.secrets."${host}-cf-tunnel-json".path;
        };
      };
    };
  };
}
