{ ... }:
{
  nix.linux-builder = {
    enable = true;
    config.virtualisation = {
      cores = 6;
      darwin-builder.memorySize = 8192;
      vz.idleTimeout = 60 * 60;
    };
  };
}
