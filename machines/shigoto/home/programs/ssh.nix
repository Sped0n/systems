{
  config,
  home,
  username,
  vars,
  ...
}: {
  programs.ssh = {
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
      "gitlab.com" =
        {
          identityFile = "${home}/.ssh/id_github";
          user = "git";
        }
        // basicTmpl;

      "orangepi" =
        {
          hostname = "10.10.2.183";
          port = 22;
          user = "orangepi";
          setEnv = {
            "TERM" = "xterm-256color";
          };
        }
        // basicTmpl;

      "tennousei" = {hostname = vars.tennousei.ipv4;} // serverTmpl;
      "tsuki" = {hostname = vars.tsuki.ipv4;} // serverTmpl;
      "suisei" = {hostname = vars.suisei.ipv4Public;} // serverTmpl;
    };
  };
}
