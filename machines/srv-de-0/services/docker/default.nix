{ ... }:
{
  imports = [
    ./filebrowser.nix
    ./forgejo.nix
    ./syncthing.nix
    ./vaultwarden.nix
    ./qb.nix
  ];

  services.my-docker = {
    enable = true;
    docuumThreshold = "25GB";
  };
}
