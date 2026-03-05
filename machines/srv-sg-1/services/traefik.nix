{ vars, ... }:
{
  services.my-traefik = {
    enable = true;
    extraDynamicConfig = {
      http = {
        middlewares.authelia.forwardauth = {
          address = "http://100.96.0.${vars."srv-de-0".meshId}:9091/api/authz/forward-auth";
          trustForwardHeader = true;
          authResponseHeaders = [
            "Remote-User"
            "Remote-Groups"
            "Remote-Name"
            "Remote-Email"
          ];
        };
        routers.api = {
          rule = "Host(`traefik-sg-1.sped0n.com`)";
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
