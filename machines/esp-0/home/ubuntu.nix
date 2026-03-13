{ functions, ... }:
{
  disabledModules = [
    (functions.fromRoot "/home/shared/gc.nix")
  ];

  services.standalone.enable = true;

  # bootstrap
  # sudo apt update && sudo apt upgrade
  # sudo apt install ssh-askpass-gnome zram-tools gnome-screenshot
  # enable zram
  # ENABLED=true
  # ALGO=zstd
  # PERCENTAGE=50
  # PRIORITY=1000
  # put `kernel.apparmor_restrict_unprivileged_userns=0` in `/etc/sysctl.d/60-apparmor-namespace.conf`
  # sudo adduser spedon dialout
}
