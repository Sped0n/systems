{ ... }:
{
  imports = [
    ./groups.nix
    ./host.nix
    ./otbr.nix
    ./packages.nix
    ./policy.nix
    ./zram.nix
  ];

  services.standalone.enable = true;
}
