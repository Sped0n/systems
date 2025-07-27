{
  config,
  home,
  secrets,
  username,
  vars,
  ...
}: {
  age.secrets."server-ssh-key" = {
    path = "${home}/.ssh/id_server";
    file = "${secrets}/ages/server-ssh-key.age";
    mode = "0400";
  };

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
      "gitlab.com" =
        {
          identityFile = "${home}/.ssh/id_github";
          user = "git";
        }
        // basicTmpl;

      "gitea" =
        {
          hostname = "tennousei";
          port = 22222;
          user = "git";
          identityFile = [
            config.age.secrets."github-ssh-key".path
          ];
        }
        // basicTmpl;

      "tennousei" = {hostname = vars.tennousei.ipv4;} // serverTmpl;
      "_tennousei" = {
        match = ''
          host tennousei exec "tailscale status"
        '';
        hostname = "tennousei";
      };

      "tsuki" = {hostname = vars.tsuki.ipv4;} // serverTmpl;
      "_tsuki" = {
        match = ''
          host tsuki exec "tailscale status"
        '';
        hostname = "tsuki";
      };

      "suisei" = {hostname = vars.suisei.ipv4Public;} // serverTmpl;
      "_suisei" = {
        match = ''
          host suisei exec "tailscale status"
        '';
        hostname = "suisei";
      };
    };
  };
}
