{ lib, ... }:
{
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
