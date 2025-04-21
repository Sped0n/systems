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
    matchBlocks = {
      "tennousei" = {
        hostname = vars.tennousei.ipv4;
        port = 12222;
        user = "${username}";
        identityFile = [
          config.age.secrets."tennousei-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };

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

      "neptune" = {
        hostname = vars.neptune.ipv4;
        port = 12222;
        user = "${username}";
        identityFile = [
          config.age.secrets."neptune-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };

      "tsuki" = {
        hostname = vars.tsuki.ipv4;
        port = 12222;
        user = "${username}";
        identityFile = [
          config.age.secrets."tsuki-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
    };
  };
}
