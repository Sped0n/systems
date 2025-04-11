{...}: {
  boot.loader = {
    timeout = 8; # Wait for x seconds to select the boot entry
    grub = {
      # Don't need to keep too many generations.
      configurationLimit = 10;

      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  # Power management
  services = {
    power-profiles-daemon = {
      enable = true;
    };
    upower.enable = true;
  };

  # Timezone
  time.timeZone = "Asia/Singapore";
}
