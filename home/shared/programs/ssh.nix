{
  config,
  home,
  secrets,
  ...
}: {
  age.secrets."github-ssh-key" = {
    path = "${home}/.ssh/id_github";
    file = "${secrets}/ages/github-ssh-key.age";
    mode = "0400";
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        identityFile = config.age.secrets."github-ssh-key".path;
        user = "git";
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
    };
  };
}
