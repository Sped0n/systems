{
  config,
  secrets,
  vars,
  ...
}:
let
  hostNames = [
    "unicorn"
    "banshee"
    "exia"
    "calibarn"
  ];
in
{
  age.secrets =
    with vars;
    {
      "builder-aarch64-ssh-key" = {
        file = "${secrets}/ages/calibarn-builder-ssh-key.age";
        mode = "0400";
        path = "${home}/.ssh/id_builder_aarch64";
      };
      "builder-x86_64-ssh-key" = {
        file = "${secrets}/ages/banshee-builder-ssh-key.age";
        mode = "0400";
        path = "${home}/.ssh/id_builder_x86_64";
      };
    }
    // (
      let
        mkSecretAttr = hostName: {
          name = "${hostName}-ssh-key";
          value = {
            file = "${secrets}/ages/${hostName}-ssh-key.age";
            mode = "0400";
            path = "${vars.home}/.ssh/id_${hostName}";
          };
        };
      in
      builtins.listToAttrs (map mkSecretAttr hostNames)
    );

  programs.ssh = {
    includes = [
      "~/.orbstack/ssh/config"
    ];
    matchBlocks =
      let
        basicBlock = {
          extraOptions = {
            "TCPKeepAlive" = "yes";
            "AddKeysToAgent" = "yes";
          };
        };
        gitBlock = {
          user = "git";
          identityFile = config.age.secrets."git-ssh-key".path;
        }
        // basicBlock;
        builderBlock = {
          port = 12222;
          user = "builder";
        }
        // basicBlock;
      in
      {
        "gitlab.com" = gitBlock;
        "git.sped0n.com" = {
          hostname = "unicorn";
          port = 22222;
        }
        // gitBlock;

        "builder-aarch64" = {
          hostname = "calibarn";
          identityFile = config.age.secrets."builder-aarch64-ssh-key".path;
        }
        // builderBlock;
        "builder-x86_64" = {
          hostname = "banshee";
          identityFile = config.age.secrets."builder-x86_64-ssh-key".path;
        }
        // builderBlock;
      }
      // (
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
              }
              // basicBlock;
            }
            {
              name = "_${hostName}";
              value = {
                match = ''
                  host ${hostName} exec "tailscale ping -c 3 --timeout 2s ${hostName}"
                '';
                hostname = hostName;
              };
            }
          ];
        in
        builtins.listToAttrs (builtins.concatMap mkMatchBlockAttrs hostNames)
      );
  };
}
