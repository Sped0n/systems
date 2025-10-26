{
  config,
  secrets,
  vars,
  ...
}:
let
  hostNames = [ "calibarn" ];
in
{
  age.secrets =
    let
      mkSecretAttr = hostName: {
        name = "${hostName}-ssh-key";
        value = {
          file = "${secrets}/ages/${hostName}-ssh-key.age";
          owner = "builder";
          mode = "0400";
        };
      };
    in
    builtins.listToAttrs (map mkSecretAttr hostNames);

  home-manager.users.builder =
    { ... }:
    {
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
      programs.ssh = {
        enable = true;
        matchBlocks =
          let
            mkMatchBlockAttrs = hostName: [
              {
                name = hostName;
                value = {
                  hostname = vars."${hostName}".ipv4;
                  port = 12222;
                  user = vars.username;
                  identityFile = [
                    config.age.secrets."${hostName}-ssh-key".path
                  ];
                  extraOptions = {
                    "TCPKeepAlive" = "yes";
                    "AddKeysToAgent" = "yes";
                  };
                };
              }
              {
                name = "_${hostName}";
                value = {
                  match = ''
                    host ${hostName} exec "tailscale status"
                  '';
                  hostname = hostName;
                };
              }
            ];
          in
          builtins.listToAttrs (builtins.concatMap mkMatchBlockAttrs hostNames);
      };
    };
}
