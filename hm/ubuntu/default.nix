{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/nixos/desktop")

    ./programs

    ./groups.nix
    ./host.nix
    ./otbr.nix
    ./packages.nix
    ./policy.nix
    ./zram.nix
  ];

  services.standalone.enable = true;
}
