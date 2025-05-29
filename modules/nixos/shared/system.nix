{lib, ...}: {
  boot.loader = {
    timeout = 8; # Wait for x seconds to select the boot entry
    grub = {
      # Don't need to keep too many generations.
      configurationLimit = 10;

      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  # Timezone
  time.timeZone = "Asia/Singapore";

  # Power management
  services = {
    power-profiles-daemon = {
      enable = true;
    };
    upower.enable = true;
  };

  # SUID Wrappers
  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # Swap
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = lib.mkDefault (1 * 1024);
      priority = 10;
    }
  ];
}
