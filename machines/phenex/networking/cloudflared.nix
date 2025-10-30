{
  config,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
{
  age.secrets."phenex-cf-tunnel-json" = {
    file = "${secrets}/ages/phenex-cf-tunnel-json.age";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    package = pkgs-unstable.cloudflared;
    tunnels = {
      "${vars.phenex.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile = config.age.secrets."phenex-cf-tunnel-json".path;
      };
    };
  };

  # FIXME: weird routing issue (perhaps something wrong on the singtel side)
  systemd.services."cloudflared-tunnel-${vars.phenex.cfTunnelId}" = {
    environment = {
      TUNNEL_REGION = "us";
    };
  };
}
