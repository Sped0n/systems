{
  config,
  secrets,
  vars,
  ...
}:
{
  age.secrets."hashed-password" = {
    file = "${secrets}/ages/hashed-password.age";
    mode = "0400";
  };

  users = {
    mutableUsers = false;
    groups = {
      docker = { };
      users.gid = 100;
    };
    users = {
      root.hashedPasswordFile = config.age.secrets."hashed-password".path;
      "${vars.username}" = {
        uid = 1000;
        hashedPasswordFile = config.age.secrets."hashed-password".path;
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
        ];
      };
    };
  };
}
