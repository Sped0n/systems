{ ... }:
{
  imports = [ ./syncthing.nix ];

  services.docuum.threshold = "2GB";
}
