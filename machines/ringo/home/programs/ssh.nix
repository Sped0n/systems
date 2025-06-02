{
  config,
  vars,
  username,
  ...
}: let
  personalServerTmpl = {
    port = 12222;
    user = "${username}";
    identityFile = [config.age.secrets."server-ssh-key".path];
    extraOptions = {
      "TCPKeepAlive" = "yes";
      "AddKeysToAgent" = "yes";
    };
  };
in {
  programs.ssh = {
    includes = [
      "~/.orbstack/ssh/config"
    ];
    matchBlocks = {
      "gitea" = {
        hostname = "100.69.27.45";
        port = 22222;
        user = "git";
        identityFile = [
          config.age.secrets."github-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };

      "tennousei" =
        {
          hostname = vars.tennousei.ipv4;
        }
        // personalServerTmpl;

      "tsuki" =
        {
          hostname = vars.tsuki.ipv4;
        }
        // personalServerTmpl;

      "suisei" =
        {
          hostname = vars.suisei.ipv4Public;
        }
        // personalServerTmpl;
    };
  };
}
