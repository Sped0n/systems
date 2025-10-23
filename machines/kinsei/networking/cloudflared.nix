{
  config,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
{
  age.secrets."kinsei-cf-tunnel-json" = {
    file = "${secrets}/ages/kinsei-cf-tunnel-json.age";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    package = pkgs-unstable.cloudflared;
    tunnels = {
      "${vars.kinsei.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile = config.age.secrets."kinsei-cf-tunnel-json".path;
      };
    };
  };
}
