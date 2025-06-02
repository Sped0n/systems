{vars, ...}: {
  programs.ssh = let
    matchBlkTmpl = {
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
      "tennousei" = {hostname = vars.tennousei.ipv4;} // matchBlkTmpl;
      "tsuki" = {hostname = vars.tsuki.ipv4;} // matchBlkTmpl;
    };
  };
}
