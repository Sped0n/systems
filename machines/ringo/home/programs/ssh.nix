{
  config,
  vars,
  username,
  ...
}: {
  programs.ssh = {
    includes = [
      "~/.orbstack/ssh/config"
    ];
    matchBlocks = let
      basicTmpl = {
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
      serverTmpl =
        {
          port = 12222;
          user = "${username}";
          identityFile = [config.age.secrets."server-ssh-key".path];
        }
        // basicTmpl;
    in {
      "gitea" =
        {
          hostname = "100.69.27.45";
          port = 22222;
          user = "git";
          identityFile = [
            config.age.secrets."github-ssh-key".path
          ];
        }
        // basicTmpl;

      "tennousei" = {hostname = vars.tennousei.ipv4;} // serverTmpl;
      "tsuki" = {hostname = vars.tsuki.ipv4;} // serverTmpl;
      "suisei" = {hostname = vars.suisei.ipv4Public;} // serverTmpl;
    };
  };
}
