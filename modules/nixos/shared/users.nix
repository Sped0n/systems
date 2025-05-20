{
  pkgs,
  username,
  home,
  vars,
  ...
}: {
  users.mutableUsers = false; # Don't allow mutation of users outside the config.

  users.groups = {
    docker = {};
    dialout = {};
  };

  users.users."${username}" = {
    inherit home;
    hashedPassword = vars.hashedPassword;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout"
    ];
    shell = pkgs.zsh;
  };

  users.users.root = {
    hashedPassword = vars.hashedPassword;
  };
}
