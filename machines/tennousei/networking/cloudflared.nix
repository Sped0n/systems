{
  pkgs-unstable,
  vars,
  config,
  ...
}: {
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
}
