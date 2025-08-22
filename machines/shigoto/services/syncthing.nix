{
  home,
  pkgs-unstable,
  username,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${home}/Documents 0755 ${username} users -"
    "d ${home}/Documents/syncthing 0755 ${username} users -"
    "d ${home}/Documents/syncthing/data 0755 ${username} users -"
    "d ${home}/Documents/syncthing/config 0755 ${username} users -"
  ];

  services = {
    syncthing = {
      enable = true;
      package = pkgs-unstable.syncthing;
      group = "users";
      user = username;
      dataDir = "${home}/Documents/syncthing/data";
      configDir = "${home}/Documents/syncthing/config";
    };
  };
}
