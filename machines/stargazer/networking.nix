{ ... }:
{
  imports = [
    ../../../modules/nixos/shared/networking.nix
  ];

  networking.hostName = "stargazer";

  services.my-tailscale.enable = true;
}
