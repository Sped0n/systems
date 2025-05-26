{
  config,
  home,
  vars,
  ...
}: {
  programs.ssh = {
    matchBlocks = {
      "gitlab.com" = {
        identityFile = "${home}/.ssh/id_github";
        user = "git";
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };

      "espressif-builder" = {
        hostname = vars.espressif-builder.ipv4;
        port = 12222;
        user = "espressif";
        identityFile = [
          config.age.secrets."espressif-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
        setEnv = {
          "TERM" = "xterm-256color";
        };
      };

      "orangepi" = {
        hostname = "10.10.2.183";
        port = 22;
        user = "orangepi";
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
        setEnv = {
          "TERM" = "xterm-256color";
        };
      };
    };
  };
}
