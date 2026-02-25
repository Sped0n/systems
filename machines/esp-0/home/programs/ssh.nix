{
  config,
  secrets,
  vars,
  ...
}:
{
  age.secrets =
    let
      mkSecretAttr = hostname: {
        name = "${hostname}-ssh-key";
        value = {
          file = "${secrets}/ages/${hostname}-ssh-key.age";
          mode = "0400";
          path = "${vars.home}/.ssh/id_${hostname}";
        };
      };
    in
    builtins.listToAttrs (map mkSecretAttr vars.serverHostnames);

  programs.ssh = {
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
      in
      {
        # --- git servers ------------------------------------------------------
        "gitlab.com" = gitBlock;
        "git.sped0n.com" = {
          hostname = vars."srv-de-0".ipv4;
          port = 12222;
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
      }
      # --- servers ------------------------------------------------------------
      // (
        let
          mkMatchBlockAttrs = hostname: [
            {
              name = hostname;
              value = {
                hostname = vars."${hostname}".ipv4;
                port = 12222;
                user = vars.username;
                identityFile = [
                  config.age.secrets."${hostname}-ssh-key".path
                ];
              };
            }
          ];
        in
        builtins.listToAttrs (builtins.concatMap mkMatchBlockAttrs vars.serverHostnames)
      );
  };
}
