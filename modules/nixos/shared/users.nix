{
  home,
  pkgs,
  username,
  vars,
  ...
}:
{
  users.mutableUsers = false; # Don't allow mutation of users outside the config.

  users.groups = {
    docker = { };
    users.gid = 100;
  };

  users.users."${username}" = {
    inherit home;
    hashedPassword = vars.hashedPassword;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    uid = 1000;
  };

  users.users.root = {
    hashedPassword = vars.hashedPassword;
  };
}
