{ config, ... }:
{
  nix.enable = false;
  determinate-nix.customSettings = config.nix.settings // {
    builders-use-substitutes = true;
  };
}
