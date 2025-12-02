{ vars, ... }:
{
  users.mutableUsers = false;

  users.groups = {
    docker = { };
    users.gid = 100;
  };

  users.users."${vars.username}" = {
    hashedPassword = vars.hashedPassword;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    uid = 1000;
  };

  users.users.root = {
    hashedPassword = vars.hashedPassword;
  };
}
