{...}: {
  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "lz4";
    memoryPercent = 50;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 1 * 1024;
      priority = 10;
    }
  ];
}
