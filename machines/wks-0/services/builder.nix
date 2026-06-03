{ ... }:
{
  services.my-linux-builder = {
    enable = true;
    customizeVm = {
      enable = true;
      cores = 6;
      memorySize = 8 * 1024;
      diskSize = 40 * 1024;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
  };
}
