{
  config,
  pkgs-unstable,
  secrets,
  vars,
  ...
}: {
  age.secrets."tennousei-cf-tunnel-json" = {
    file = "${secrets}/ages/tennousei-cf-tunnel-json.age";
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    package = pkgs-unstable.cloudflared;
    tunnels = {
      "${vars.tennousei.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile =
          config.age.secrets."tennousei-cf-tunnel-json".path;
      };
    };
  };

  # FIXME: https://github.com/cloudflare/cloudflared/issues/1485
  #        cloudflared drops HTTP request body when Content-Length is missing
  systemd.services."cloudflared-tunnel-${vars.tennousei.cfTunnelId}"
    .environment
    .TUNNEL_TRANSPORT_PROTOCOL = "http2";
}
