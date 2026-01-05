{
  config,
  secrets,
  vars,
  ...
}:
let
  hostNames = [
    "srv-de-0"
    "srv-sg-0"
    "srv-nl-0"
    "srv-sg-1"
  ];
in
{
  age.secrets =
    with vars;
    {
      "openwrt-ssh-key" = {
        file = "${secrets}/ages/openwrt-ssh-key.age";
        mode = "0400";
        path = "${home}/.ssh/id_openwrt";
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
        gitBlock = {
          user = "git";
          identityFile = config.age.secrets."git-ssh-key".path;
        };
        builderBlock = {
          port = 12222;
          user = "builder";
        };
        openwrtBlock = {
          port = 12222;
          user = "root";
          identityFile = config.age.secrets."openwrt-ssh-key".path;
        };
      in
      {
        # --- git servers ------------------------------------------------------
        "gitlab.com" = gitBlock;
        "git.sped0n.com" = {
          hostname = "10.42.0.${vars."srv-de-0".meshId}";
          port = 22222;
        }
        // gitBlock;

        # --- builders ---------------------------------------------------------
        "builder-aarch64" = {
          hostname = vars.srv-sg-1.ipv4;
          identityFile = config.age.secrets."srv-sg-1-ssh-key".path;
        }
        // builderBlock;
        "builder-x86_64" = {
          hostname = vars.srv-sg-0.ipv4;
          identityFile = config.age.secrets."srv-sg-0-ssh-key".path;
        }
        // builderBlock;

        # --- routers ----------------------------------------------------------
        "openwrt" = {
          hostname = "192.168.31.1";
        }
        // openwrtBlock;
      }
      # --- servers ------------------------------------------------------------
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
              };
            }
          ];
        in
        builtins.listToAttrs (builtins.concatMap mkMatchBlockAttrs hostNames)
      );
  };
}
