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
    settings = {
      "*" = {
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
        identitiesOnly = true;
        TCPKeepAlive = "yes";
      };

      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        identityFile = config.age.secrets."git-ssh-key".path;
        user = "git";
      };
    };
  };
}
