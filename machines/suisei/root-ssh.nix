{vars, ...}: {
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
}
