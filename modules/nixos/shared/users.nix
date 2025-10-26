{ pkgs, vars, ... }:
{
  users.mutableUsers = false;

  users.groups = {
    docker = { };
    users.gid = 100;
  };

  users.users."${vars.username}" = {
    home = vars.home;
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
