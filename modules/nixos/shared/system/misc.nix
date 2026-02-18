{ ... }:
{
  # timezone
  time.timeZone = "Asia/Singapore";
  # logrotate
  services.logrotate.enable = true;
  # time sync
  services.timesyncd.enable = true;
  # don't install the /lib/ld-linux.so.2 stub, this saves one instance of nixpkgs.
  environment.ldso32 = null;
  # ensure a clean & sparkling /tmp on fresh boots.
  boot.tmp.cleanOnBoot = true;
}
