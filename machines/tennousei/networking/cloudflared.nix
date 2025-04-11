{
  vars,
  config,
  ...
}: {
  services.cloudflared = {
    enable = true;
    tunnels = {
      "${vars.tennousei.cfTunnelId}" = {
        default = "http_status:404";
        credentialsFile =
          config.age.secrets."tennousei-cf-tunnel-json".path;
      };
    };
  };
}
