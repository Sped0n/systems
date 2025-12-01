{
  config,
  secrets,
  vars,
  ...
}:
{
  age.secrets."git-ssh-key" = {
    path = "${vars.home}/.ssh/id_git";
    mode = "0400";
    file = "${secrets}/ages/git-ssh-key.age";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
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
