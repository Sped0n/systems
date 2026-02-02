{ config, lib, ... }:
let
  my-swap = config.services.my-swap;
in
{
  options.services.my-swap = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the custom swap module.";
    };

    swapFileSize = lib.mkOption {
      type = lib.types.int;
      default = (1 * 1024);
      description = "Size of the swap file in MiB.";
    };
  };

  config = lib.mkIf my-swap.enable {
    zramSwap = {
      enable = true;
      memoryPercent = 50;
      priority = 100;
    };

    swapDevices = [
      {
        device = "/swapfile";
        size = my-swap.swapFileSize;
        priority = 10;
      }
    ];
  };
}
