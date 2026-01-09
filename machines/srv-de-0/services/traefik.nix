{ vars, ... }:
{
  services.my-traefik = {
    enable = true;
    dynamicConfigOptions = {
      http = {
        middlewares.authelia.forwardauth = {
          address = "http://100.96.0.${vars."srv-de-0".warpId}:9091/api/authz/forward-auth";
          trustForwardHeader = true;
          authResponseHeaders = [
            "Remote-User"
            "Remote-Groups"
            "Remote-Name"
            "Remote-Email"
          ];
        };
        routers.api = {
          rule = "Host(`traefik-de-0.sped0n.com`)";
          entryPoints = [ "https" ];
          tls = true;
          service = "api@internal";
          middlewares = [
            "authelia@file"
            "cftunnel@file"
          ];
        };
      };
    };
  };
}
