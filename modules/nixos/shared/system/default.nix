{ ... }:
{
  imports = [
    ./grub.nix
    ./power.nix
    ./security.nix
    ./swap.nix
  ];

  # misc
  time.timeZone = "Asia/Singapore";
  services.logrotate.enable = true;
  system.stateVersion = "24.11";
}
