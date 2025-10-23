{
  config,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
{
  age.secrets."banshee-cf-tunnel-json" = {
    file = "${secrets}/ages/banshee-cf-tunnel-json.age";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    package = pkgs-unstable.cloudflared;
    tunnels = {
      "${vars.banshee.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile = config.age.secrets."banshee-cf-tunnel-json".path;
      };
    };
  };
}
