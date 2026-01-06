{ vars, ... }:
{
  imports = [
    ./syncthing.nix
    ./vaultwarden.nix
    ./qb.nix
  ];

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/sharing 0755 ${username} users -"
    "d ${home}/storage 0755 ${username} users -"
  ];

  services.docuum.threshold = "25GB";
}
