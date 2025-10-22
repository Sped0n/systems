{ ... }:
{
  imports = [
    ../../../modules/nixos/shared/networking.nix
  ];

  networking.hostName = "shigoto";

  services.my-tailscale.enable = true;
}
