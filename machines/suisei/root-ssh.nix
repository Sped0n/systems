{
  vars,
  secrets,
  ...
}: {
  age.secrets = {
    "server-ssh-key" = {
      path = "/root/.ssh/id_server";
      file = "${secrets}/ages/server-ssh-key.age";
      owner = "root";
      mode = "0400";
    };
  };

  home-manager = {
    users.root = {...}: {
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
      programs.ssh = let
        serverTmpl = {
          port = 12222;
          user = "root";
          identityFile = ["/root/.ssh/id_server"];
          extraOptions = {
            "TCPKeepAlive" = "yes";
            "AddKeysToAgent" = "yes";
          };
        };
      in {
        enable = true;
        matchBlocks = {
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
        };
      };
    };
  };
}
