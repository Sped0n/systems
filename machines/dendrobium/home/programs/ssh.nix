{
  config,
  home,
  secrets,
  username,
  vars,
  ...
}:
{
  age.secrets."server-ssh-key" = {
    path = "${home}/.ssh/id_server";
    file = "${secrets}/ages/server-ssh-key.age";
    mode = "0400";
  };

  programs.ssh = {
    includes = [
      "~/.orbstack/ssh/config"
    ];
    matchBlocks =
      let
        basicTmpl = {
          extraOptions = {
            "TCPKeepAlive" = "yes";
            "AddKeysToAgent" = "yes";
          };
        };
        serverTmpl = {
          port = 12222;
          user = "${username}";
          identityFile = config.age.secrets."server-ssh-key".path;
        }
        // basicTmpl;
      in
      {
        "gitlab.com" = {
          identityFile = config.age.secrets."git-ssh-key".path;
          user = "git";
        }
        // basicTmpl;

        "git.sped0n.com" = {
          hostname = "unicorn";
          port = 22222;
          identityFile = config.age.secrets."git-ssh-key".path;
          user = "git";
        }
        // basicTmpl;

        "unicorn" = {
          hostname = vars.unicorn.ipv4;
        }
        // serverTmpl;
        "_unicorn" = {
          match = ''
            host unicorn exec "tailscale status"
          '';
          hostname = "unicorn";
        };

        "exia" = {
          hostname = vars.exia.ipv4;
        }
        // serverTmpl;
        "_exia" = {
          match = ''
            host exia exec "tailscale status"
          '';
          hostname = "exia";
        };

        "calibarn" = {
          hostname = vars.calibarn.ipv4Public;
        }
        // serverTmpl;
        "_calibarn" = {
          match = ''
            host calibarn exec "tailscale status"
          '';
          hostname = "calibarn";
        };

        "banshee" = {
          hostname = vars.banshee.ipv4;
        }
        // serverTmpl;
        "_banshee" = {
          match = ''
            host banshee exec "tailscale status"
          '';
          hostname = "banshee";
        };
      };
  };
}
