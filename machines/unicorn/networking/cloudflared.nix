{
  config,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
{
  age.secrets."unicorn-cf-tunnel-json" = {
    file = "${secrets}/ages/unicorn-cf-tunnel-json.age";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    package = pkgs-unstable.cloudflared;
    tunnels = {
      "${vars.unicorn.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile = config.age.secrets."unicorn-cf-tunnel-json".path;
      };
    };
  };

  # FIXME: weird routing issue (perhaps something wrong on the singtel side)
  systemd.services."cloudflared-tunnel-${vars.unicorn.cfTunnelId}" = {
    environment = {
      TUNNEL_REGION = "us";
    };
  };
}
