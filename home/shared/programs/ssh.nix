{
  config,
  home,
  secrets,
  ...
}:
{
  age.secrets."git-ssh-key" = {
    path = "${home}/.ssh/id_git";
    file = "${secrets}/ages/git-ssh-key.age";
    mode = "0400";
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        identityFile = config.age.secrets."git-ssh-key".path;
        user = "git";
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
    };
  };
}
