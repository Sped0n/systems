{
  config,
  vars,
  username,
  ...
}: {
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "tennousei" = {
        hostname = vars.tennousei.ipv4;
        port = 22;
        user = "${username}";
        identityFile = [
          config.age.secrets."deploy-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };

      "tsuki" = {
        hostname = vars.tsuki.ipv4;
        port = 22;
        user = "${username}";
        identityFile = [
          config.age.secrets."deploy-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
    };
  };
}
